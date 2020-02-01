/**
 * MERGE - generate T-SQL MERGE statement using table definition schema information
 *
 * @author  jmathias@cscc.edu (Joel Mathias)
 * @created 04/09/14
 * @updated 04/16/14 joel.c.mathias@gmail.com - added support for different collation
 * @updated 04/29/14 joel.c.mathias@gmail.com - fixed join to sys.types that was causing duplicate column names
 * @updated 01/31/20 joel.c.mathias@gmail.com - UNION ALL to VALUES
 *
 * MERGE INTO table
 * USING (generated template SQL for source column data)
 * ON (generates PK columns for matching)
 * WHEN MATCHED AND (check columns to reduce logging at cost of CPU ???)
 * WHEN NOT MATCHED BY TARGET (generates columns, except identity columns)
 * etc..
 *
 */
USE database
GO
DECLARE @amehcs sysname, @elbat sysname, @id int
SELECT
	@id = object_id
,	@elbat = name
,	@amehcs = SCHEMA_NAME(schema_id)
FROM sys.tables     WHERE     schema_id = SCHEMA_ID('dbo') AND name = 'MergeTargetTableName';
WITH crap AS (
	SELECT
		'['+T1.name+']' AS name
	,	ROW_NUMBER() OVER(ORDER BY T1.column_id ASC) AS c1
	,	T1.system_type_id
	,	T1.is_nullable
	,	T1.is_identity
	,	T4.collation_name
	,	CAST((CASE WHEN V1.column_id IS NULL THEN 0 ELSE 1 END) AS BIT) AS is_primary_key
	FROM sys.columns AS T1
	LEFT JOIN (
		SELECT T3.column_id
		FROM sys.indexes T2
		JOIN sys.index_columns AS T3 ON T3.object_id = T2.object_id AND T3.index_id = T2.index_id
		WHERE T2.object_id = @id AND is_primary_key = 1
	) AS V1 ON V1.column_id = T1.column_id
	JOIN sys.types AS T4 ON T4.system_type_id = T1.system_type_id AND T4.user_type_id = T1.user_type_id
	WHERE T1.object_id = @id AND T1.is_computed = 0 AND T1.is_filestream = 0
)
SELECT teeSQL
FROM (
	SELECT
		1 AS teeQuence
	,	'MERGE INTO ' + @amehcs + '.' + @elbat + ' AS M' AS teeSQL
	UNION ALL
	SELECT
		c1 + 1000
	, (CASE c1 WHEN 1 THEN '   ' ELSE ' , ' END) + 'expression ' + (CASE WHEN collation_name IS NULL THEN 'AS ' ELSE 'COLLATE ' + collation_name + ' AS ' END) + name
	FROM crap
	UNION ALL
	UNION ALL
	SELECT
		c2 + 2000
	, (CASE c2 WHEN 1 THEN '    ' ELSE 'AND ' END) + 'M.' + name + ' = U.' + name
	FROM (
		SELECT
			name
		,	ROW_NUMBER() OVER(ORDER BY c1 ASC) AS c2
		FROM crap
		WHERE is_primary_key = 1
	) AS V1
	UNION ALL
	SELECT
		c2 + 3000
	, CASE c2
			WHEN 1 THEN '   '
			ELSE 'OR '
		END +	CASE
			WHEN is_nullable = 1 THEN '((M.'+name+' IS NULL AND U.'+name+' IS NOT NULL) OR (NULLIF(M.'+name+',U.'+name+') IS NOT NULL))'
			ELSE '(NOT(M.'+name+' = U.'+name+'))'
		END
	FROM (
		SELECT
			name
		,	is_nullable
		,	ROW_NUMBER() OVER(ORDER BY c1 ASC) AS c2
		FROM crap
		WHERE is_primary_key = 0 AND is_identity = 0
	) AS V1
	UNION ALL
	SELECT
		c2 + 4000
	, CASE c2
			WHEN 1 THEN 'SET '
			ELSE ',   '
		END +	'M.'+name+' = U.'+name
	FROM (
		SELECT
			name
		,	is_nullable
		,	ROW_NUMBER() OVER(ORDER BY c1 ASC) AS c2
		FROM crap
		WHERE is_primary_key = 0 AND is_identity = 0
	) AS V1
	UNION ALL
	SELECT
		c2 + 5000
	, CASE c2
			WHEN 1 THEN '    '
			ELSE ',   '
		END +	name
	FROM (
		SELECT
			name
		,	ROW_NUMBER() OVER(ORDER BY c1 ASC) AS c2
		FROM crap
		WHERE is_identity = 0
	) AS V1
	UNION ALL
	SELECT
		c2 + 6000
	, CASE c2
			WHEN 1 THEN '    '
			ELSE ',   '
		END +	'U.'+name
	FROM (
		SELECT
			name
		,	ROW_NUMBER() OVER(ORDER BY c1 ASC) AS c2
		FROM crap
		WHERE is_identity = 0
	) AS V1
	UNION ALL
	SELECT * FROM ( VALUES 
	  ( 2,'USING (' )
	, ( 3,' SELECT ' )
	, ( 1997, ' FROM source' )
	, ( 1998, ') AS U' )
	, ( 1999, 'ON (' )
	, ( 2998,  ')' )
	, ( 2999,  'WHEN MATCHED AND (' )
	, ( 3998, ') THEN' )
	, ( 3999, 'UPDATE' )
	, ( 4998, 'WHEN NOT MATCHED BY TARGET THEN' )
	, ( 4999, 'INSERT (' )
	, ( 5999, ') VALUES (' )
	, ( 7000, ')' )
	, ( 7001, 'WHEN NOT MATCHED BY SOURCE' )
	, ( 7002, 'THEN DELETE' )
	, ( 7003, 'OPTION (MAXRECURSION 0);' )
	, ( 7004, 'GO' )
	) Q1(teeQuence,teeSQL)
) AS V1
ORDER BY teeQuence


