SELECT
CAST('ТоварыОрганизаций'::mvarchar AS MVARCHAR(25)),
T3._Fld58099RRef,
T5._Fld59819RRef,
T5._Fld59880RRef,
T3._Fld58100RRef,
T3._Fld58101RRef,
T3._Fld58103RRef,
T3._Fld58106RRef,
T1.Fld51157RRef,
T1.Fld51160RRef,
T1.Fld51158RRef,
T1.Fld51161InitialBalance_,
T1.Fld51161FinalBalance_,
T1.Fld51161Receipt_,
T1.Fld51161Expense_,
T1.SecondPeriod_,
CASE WHEN (T1.Recorder_TYPE = '\\001'::bytea AND T1.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T1.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T1.Recorder_TYPE END,
CASE WHEN (T1.Recorder_TYPE = '\\001'::bytea AND T1.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T1.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T1.Recorder_RTRef END,
CASE WHEN (T1.Recorder_TYPE = '\\001'::bytea AND T1.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T1.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T1.Recorder_RRRef END,
T6._Description,
T6._Fld112338RRef,
CAST(7 AS NUMERIC),
T6._Description,
T3._Fld58099RRef,
T5._Description,
CAST(CAST(9 AS NUMERIC) AS NUMERIC(2, 0)),
T5._Fld59820,
T5._Fld59880RRef,
T5._Fld59819RRef,
T5._Description,
T7._Code,
T7._Fld112360RRef,
T7._Fld112361,
CAST(11 AS NUMERIC),
T7._Code,
T1.Fld51158RRef,
T8._Description,
CAST(13 AS NUMERIC),
T8._Description,
CASE WHEN (T1.Recorder_TYPE = '\\001'::bytea AND T1.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T1.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T1.Recorder_TYPE END,
CASE WHEN (T1.Recorder_TYPE = '\\001'::bytea AND T1.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T1.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T1.Recorder_RTRef END,
CASE WHEN (T1.Recorder_TYPE = '\\001'::bytea AND T1.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T1.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T1.Recorder_RRRef END,
CAST(15 AS NUMERIC),
T3._Fld58101RRef,
T9._Description,
CAST(17 AS NUMERIC),
T9._Description,
T3._Fld58106RRef,
T10._Description,
CAST(19 AS NUMERIC),
T10._Description,
T3._Fld58100RRef,
T11._Description,
CAST(21 AS NUMERIC),
T11._Description
FROM (SELECT
T2._SecondPeriod AS SecondPeriod_,
T2._Recorder_TYPE AS Recorder_TYPE,
T2._Recorder_RTRef AS Recorder_RTRef,
T2._Recorder_RRRef AS Recorder_RRRef,
T2._Fld51157RRef AS Fld51157RRef,
T2._Fld51160RRef AS Fld51160RRef,
T2._Fld51158RRef AS Fld51158RRef,
T2._Fld51161Receipt AS Fld51161Receipt_,
T2._Fld51161Expense AS Fld51161Expense_,
T2._Fld51161InitialBalance AS Fld51161InitialBalance_,
T2._Fld51161FinalBalance AS Fld51161FinalBalance_
FROM pg_temp.tt50 T2) T1
INNER JOIN _Reference298 T3
LEFT OUTER JOIN _Reference189 T4
ON (T3._Fld58110RRef = T4._IDRRef) AND (T4._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference366X1 T5
ON (T3._Fld58099RRef = T5._IDRRef) AND (T5._Fld2488 = CAST(0 AS NUMERIC))
ON (T1.Fld51157RRef = T3._IDRRef) AND (((''::mvarchar = ''::mvarchar) AND (T3._Fld58105RRef = '\\212Y\\255I\\353A\\263v@\\237\\371\\302\\321{\\204\\203'::bytea) OR (''::mvarchar = 'ДвиженияТоваровПереданных'::mvarchar) AND (T3._Fld58105RRef = '\\253;\\372MU\\206\\013:L\\360Ba\\254\\341Fi'::bytea) AND (T4._Fld55212RRef = '\\235-\\351h\\016\\327\\261}A\\210*\\375\\375(?\\262'::bytea) OR (''::mvarchar = 'ДвиженияТоваровПереданныхНаКомиссию25'::mvarchar) AND (T3._Fld58105RRef = '\\253;\\372MU\\206\\013:L\\360Ba\\254\\341Fi'::bytea) AND (T4._Fld55212RRef = '\\267\\006\\006\\020\\032U\\276\\314G\\350\\277\\021;N\\250\\303'::bytea) AND T4._Fld104406 = TRUE) OR (''::mvarchar = 'ДвиженияТоваровПереданныхПереработчикам'::mvarchar) AND (T3._Fld58105RRef = '\\253;\\372MU\\206\\013:L\\360Ba\\254\\341Fi'::bytea) AND (T4._Fld55212RRef = '\\213Q\\3747s\\023\\330\\303HP\\346T\\245YBR'::bytea))
LEFT OUTER JOIN _Reference342 T6
ON (T3._Fld58103RRef = T6._IDRRef) AND (T6._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference370X1 T7
ON (T1.Fld51160RRef = T7._IDRRef) AND (T7._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference395 T8
ON (T1.Fld51158RRef = T8._IDRRef) AND (T8._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference615 T9
ON (T3._Fld58101RRef = T9._IDRRef) AND (T9._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference626 T10
ON (T3._Fld58106RRef = T10._IDRRef) AND (T10._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference791 T11
ON (T3._Fld58100RRef = T11._IDRRef) AND (T11._Fld2488 = CAST(0 AS NUMERIC))
WHERE ((T3._Fld2488 = CAST(0 AS NUMERIC))) AND ((T3._Fld58099RRef = '\\271\\201\\014\\304z5,\\031\\021\\347xSp&\\313\\002'::bytea))
UNION ALL SELECT
'РезервыТоваровОрганизаций'::mvarchar,
T15._Fld58099RRef,
T17._Fld59819RRef,
T17._Fld59880RRef,
T15._Fld58100RRef,
T15._Fld58101RRef,
T15._Fld58103RRef,
T15._Fld58106RRef,
T12.Fld50630RRef,
T12.Fld50633RRef,
T12.Fld50631RRef,
T12.Fld50635InitialBalance_,
T12.Fld50635FinalBalance_,
T12.Fld50635Receipt_,
T12.Fld50635Expense_,
T12.SecondPeriod_,
CASE WHEN (T12.Recorder_TYPE = '\\001'::bytea AND T12.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T12.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T12.Recorder_TYPE END,
CASE WHEN (T12.Recorder_TYPE = '\\001'::bytea AND T12.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T12.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T12.Recorder_RTRef END,
CASE WHEN (T12.Recorder_TYPE = '\\001'::bytea AND T12.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T12.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T12.Recorder_RRRef END,
T18._Description,
T18._Fld112338RRef,
CAST(8 AS NUMERIC),
T18._Description,
T15._Fld58099RRef,
T17._Description,
CAST(10 AS NUMERIC),
T17._Fld59820,
T17._Fld59880RRef,
T17._Fld59819RRef,
T17._Description,
T19._Code,
T19._Fld112360RRef,
T19._Fld112361,
CAST(12 AS NUMERIC),
T19._Code,
T12.Fld50631RRef,
T20._Description,
CAST(14 AS NUMERIC),
T20._Description,
CASE WHEN (T12.Recorder_TYPE = '\\001'::bytea AND T12.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T12.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T12.Recorder_TYPE END,
CASE WHEN (T12.Recorder_TYPE = '\\001'::bytea AND T12.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T12.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T12.Recorder_RTRef END,
CASE WHEN (T12.Recorder_TYPE = '\\001'::bytea AND T12.Recorder_RTRef = '\\000\\000\\000\\000'::bytea AND T12.Recorder_RRRef = '\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000\\000'::bytea) THEN CAST(NULL AS BYTEA) ELSE T12.Recorder_RRRef END,
CAST(16 AS NUMERIC),
T15._Fld58101RRef,
T21._Description,
CAST(18 AS NUMERIC),
T21._Description,
T15._Fld58106RRef,
T22._Description,
CAST(20 AS NUMERIC),
T22._Description,
T15._Fld58100RRef,
T23._Description,
CAST(22 AS NUMERIC),
T23._Description
FROM (SELECT
T13._SecondPeriod AS SecondPeriod_,
T13._Recorder_TYPE AS Recorder_TYPE,
T13._Recorder_RTRef AS Recorder_RTRef,
T13._Recorder_RRRef AS Recorder_RRRef,
T13._Fld50630RRef AS Fld50630RRef,
T13._Fld50632RRef AS Fld50632RRef,
T13._Fld50633RRef AS Fld50633RRef,
T13._Fld50631RRef AS Fld50631RRef,
T13._Fld50635Receipt AS Fld50635Receipt_,
T13._Fld50635Expense AS Fld50635Expense_,
T13._Fld50635InitialBalance AS Fld50635InitialBalance_,
T13._Fld50635FinalBalance AS Fld50635FinalBalance_
FROM pg_temp.tt51 T13) T12
LEFT OUTER JOIN _Reference101 T14
ON (T12.Fld50632RRef = T14._IDRRef) AND (T14._Fld2488 = CAST(0 AS NUMERIC))
INNER JOIN _Reference298 T15
LEFT OUTER JOIN _Reference189 T16
ON (T15._Fld58110RRef = T16._IDRRef) AND (T16._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference366X1 T17
ON (T15._Fld58099RRef = T17._IDRRef) AND (T17._Fld2488 = CAST(0 AS NUMERIC))
ON (T12.Fld50630RRef = T15._IDRRef) AND (((''::mvarchar = ''::mvarchar) AND (T15._Fld58105RRef = '\\212Y\\255I\\353A\\263v@\\237\\371\\302\\321{\\204\\203'::bytea) OR (''::mvarchar = 'ДвиженияТоваровПереданных'::mvarchar) AND (T15._Fld58105RRef = '\\253;\\372MU\\206\\013:L\\360Ba\\254\\341Fi'::bytea) AND (T16._Fld55212RRef = '\\235-\\351h\\016\\327\\261}A\\210*\\375\\375(?\\262'::bytea) OR (''::mvarchar = 'ДвиженияТоваровПереданныхНаКомиссию25'::mvarchar) AND (T15._Fld58105RRef = '\\253;\\372MU\\206\\013:L\\360Ba\\254\\341Fi'::bytea) AND (T16._Fld55212RRef = '\\267\\006\\006\\020\\032U\\276\\314G\\350\\277\\021;N\\250\\303'::bytea) AND T16._Fld104406 = TRUE) OR (''::mvarchar = 'ДвиженияТоваровПереданныхПереработчикам'::mvarchar) AND (T15._Fld58105RRef = '\\253;\\372MU\\206\\013:L\\360Ba\\254\\341Fi'::bytea) AND (T16._Fld55212RRef = '\\213Q\\3747s\\023\\330\\303HP\\346T\\245YBR'::bytea) AND (NOT (((T14._Fld53293RRef = '\\265\\353\\371\\272ds\\015\\241Ak\\365\\324!=\\251\\231'::bytea)))))
LEFT OUTER JOIN _Reference342 T18
ON (T15._Fld58103RRef = T18._IDRRef) AND (T18._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference370X1 T19
ON (T12.Fld50633RRef = T19._IDRRef) AND (T19._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference395 T20
ON (T12.Fld50631RRef = T20._IDRRef) AND (T20._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference615 T21
ON (T15._Fld58101RRef = T21._IDRRef) AND (T21._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference626 T22
ON (T15._Fld58106RRef = T22._IDRRef) AND (T22._Fld2488 = CAST(0 AS NUMERIC))
LEFT OUTER JOIN _Reference791 T23
ON (T15._Fld58100RRef = T23._IDRRef) AND (T23._Fld2488 = CAST(0 AS NUMERIC))
WHERE ((T15._Fld2488 = CAST(0 AS NUMERIC))) AND ((T15._Fld58099RRef = '\\271\\201\\014\\304z5,\\031\\021\\347xSp&\\313\\002'::bytea))