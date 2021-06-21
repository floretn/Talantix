----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--1 Даты регистрации
--Вывести количество контрактов, зарегистрированных в системе за каждый день за последние 5 дней 

--Вариант 1: за последние 5 каледндарных дней. Если в какой-то день не было зарегестрировано контрактов, этот день просто не будет указан.
SELECT DT_REG, COUNT(ID_CONTRACT_INST)
FROM CONTRACTS 
WHERE DT_REG > 'NOW'::DATE - INTEGER '5'
GROUP BY DT_REG

--Вариант 2: за последние 5 дней, в которые были зарегестрированы контракты. Если в таблице есть всего 4 даты, то результат будет состоять из 4 строк.
SELECT DT_REG, COUNT(ID_CONTRACT_INST)
FROM CONTRACTS
GROUP BY DT_REG 
ORDER BY DT_REG DESC
LIMIT 5

--Вариант 3: за последние 5 каледндарных дней. Будут учтены отсутоствующие дни (то есть количество контрактов будет выведено равным 0).

--DROP FUNCTION IF EXISTS TASK_1() CASCADE;
CREATE OR REPLACE FUNCTION TASK_1(
OUT DT_REG_1 DATE, 
OUT COUNT_1 BIGINT)
RETURNS SETOF RECORD AS  
$BODY$
/**
* Функция подсчёта количества заключённых контрактов за последние 5 дней
*@version 21/06/2021
*@return 5 строк с датой и количеством контрактов.
*/
DECLARE
    I INTEGER;
BEGIN
	I = 0;
	WHILE I < 5 LOOP
		RETURN QUERY 
			SELECT 'NOW'::DATE - I, COALESCE((SELECT COUNT(ID_CONTRACT_INST)
								FROM CONTRACTS 
								WHERE DT_REG = 'NOW'::DATE - I
								GROUP BY DT_REG), 0);
		I = I + 1;
	END LOOP;
	RETURN;
END;
$BODY$
LANGUAGE PLPGSQL;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--2 Отчёт по статусам
--Вывести количество контрактов для каждого значения статуса контракта из списка: A - активен, B - заблокирован, C - расторгнут. 
--Результат: статус, «словесное» наименование статуса, количество контрактов.
SELECT V_STATUS, 'активен' AS DESCRIPTION, COUNT(ID_CONTRACT_INST)
FROM CONTRACTS 
WHERE V_STATUS = 'A'
GROUP BY V_STATUS, DESCRIPTION
UNION
SELECT V_STATUS, 'заблокирован' AS DESCRIPTION, COUNT(ID_CONTRACT_INST)
FROM CONTRACTS 
WHERE V_STATUS = 'B'
GROUP BY V_STATUS, DESCRIPTION
UNION
SELECT V_STATUS, 'расторгнут' AS DESCRIPTION, COUNT(ID_CONTRACT_INST)
FROM CONTRACTS 
WHERE V_STATUS = 'C'
GROUP BY V_STATUS, DESCRIPTION

----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--3 «Пустые» филиалы
--Вывести наименования филиалов, в которых нет ни одного активного контракта.
SELECT V_NAME
FROM DEPARTMENTS D
WHERE (SELECT COUNT(ID_CONTRACT_INST) 
	FROM CONTRACTS 
	WHERE ID_DEPARTMENT = D.ID_DEPARTMENT) = 0
	
----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--4 Счет
--По контракту (v_ext_ident = ‘XXX’) после каждого события (оказанная услуга, платеж) выставляют счет, в котором в поле f_sum отображается сумма всех неоплаченных услуг на тот момент. 
--Требуется вывести задолженность абонента на произвольную дату

--DROP FUNCTION IF EXISTS TASK_4(INTEGER, DATE) CASCADE;
CREATE OR REPLACE FUNCTION TASK_4(
IN ID_CONTRACT_RND INTEGER,
IN DATE_RND DATE,
OUT F_SUM_ALL NUMERIC)
RETURNS NUMERIC AS  
$BODY$
/**
* Функция подсчёта задолженности клиента на определённую дату
*@version 21/06/2021
*@param DATE_RND: дата для подсчёта задолженностей.
*@return возвращает сумму задолженностей за дату
*/
BEGIN

	SELECT SUM(F_SUM) FROM BILLS
	INTO F_SUM_ALL
	WHERE DT_EVENT = DATE_RND AND ID_CONTRACT_INST = ID_CONTRACT_RND;
	RETURN;
END;
$BODY$
LANGUAGE PLPGSQL;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--5 Услуги
--Напишите процедуру для извлечения данных из таблицы SERVICE, так, чтобы на вход она могла принимать ID услуги (переменная pID). 
--Обратить внимание на то, что она может быть null – в этом случае нужно выводить все записи. 
--На выход процедура должна возвращать курсор (переменная dwr) в виде полей ID_SERVICE, V_NAME, CNT (количестов таких услуг у абонентов) с сортировкой по V_NAME.

--DROP FUNCTION IF EXISTS TASK_5(INTEGER) CASCADE;
CREATE OR REPLACE FUNCTION TASK_5(IN ID_SER INTEGER)
RETURNS REFCURSOR AS
$BODY$
/**
* Функция извлечения данных из таблицы SERVICE + количество этих услуг у абонентов.
*@version 21/06/2021
*@param ID_SER: id услуги. Может быть null, тогда будет возвращена информация обо всех строках таблицы.
*@return возвращает курсор по данным из таблицы SERVICE + количество этих услуг у абонентов.
*/
DECLARE 
	 _r REFCURSOR := '_r'; 
BEGIN
	OPEN _r FOR
		SELECT S.ID_SERVICE, S.V_NAME, COUNT(SS.ID_SERVICE_INST) AS CNT FROM SERVICE S
		LEFT JOIN SERVICES SS ON (SS.ID_SERVICE = S.ID_SERVICE)
		WHERE S.ID_SERVICE = COALESCE(ID_SER, S.ID_SERVICE)
		GROUP BY S.ID_SERVICE, S.V_NAME
		ORDER BY S.V_NAME;
	RETURN _r; 
END;
$BODY$
LANGUAGE PLPGSQL;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Напишите курсор CUR, который для выборки строк из SERVICES по условиям ID_SERVICE  не равно 1234 и ID_TARIFF_PLAN равно 567, будет производить изменение поля DT_STOP в начало текущего дня.

BEGIN;
DO
$BODY$
DECLARE
	X SERVICES%ROWTYPE;
	MY_COOL_CURSOR CURSOR IS SELECT * FROM SERVICES WHERE ID_SERVICE != 1234 AND ID_TARIFF_PLAN = 567;
BEGIN
	FOR X IN MY_COOL_CURSOR
	LOOP
		UPDATE SERVICES SET DT_STOP = 'NOW'::DATE WHERE CURRENT OF MY_COOL_CURSOR;
	END LOOP;
END
$BODY$;
END;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--7 Уникальные услуги
--Вывести наименования услуг, которые являются уникальными в рамках филиалов, т.е. таких услуг, которые есть только в конкретном филиале и ни в каком другом.
SELECT V_NAME
FROM(
	SELECT S.V_NAME, COUNT(DISTINCT DS.ID_DEPARTMENT) AS CNT FROM SERVICE S
	LEFT JOIN SERVICES SS ON (S.ID_SERVICE = SS.ID_SERVICE)
	LEFT JOIN CONTRACTS CS ON (CS.ID_CONTRACT_INST = SS.ID_CONTRACT_INST)
	LEFT JOIN DEPARTMENTS DS ON (DS.ID_DEPARTMENT = CS.ID_DEPARTMENT)
	GROUP BY S.V_NAME
) P
WHERE P.CNT = 1

----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--8 Популярные услуги
--Вывести наименования тарифных планов для 5 самых популярных услуг
SELECT TP.V_NAME
FROM(
	SELECT SS.ID_TARIFF_PLAN, COUNT(DISTINCT DS.ID_DEPARTMENT) AS CNT FROM SERVICE S
	LEFT JOIN SERVICES SS ON (S.ID_SERVICE = SS.ID_SERVICE)
	LEFT JOIN CONTRACTS CS ON (CS.ID_CONTRACT_INST = SS.ID_CONTRACT_INST)
	LEFT JOIN DEPARTMENTS DS ON (DS.ID_DEPARTMENT = CS.ID_DEPARTMENT)
	GROUP BY SS.ID_TARIFF_PLAN
) P
LEFT JOIN TARIFF_PLAN TP ON (TP.ID_TARIFF_PLAN = P.ID_TARIFF_PLAN)
ORDER BY P.CNT DESC
LIMIT 5

----------------------------------------------------------------------------------------------------------------------------------------------------------------------





















