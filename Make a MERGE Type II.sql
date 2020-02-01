/**
 * MERGE - generate T-SQL MERGE statement for a Type II dimension table using table definition schema information
 *
 * @author  jmathias@cscc.edu (Joel Mathias)
 * @created 04/29/14
 * @updated 06/23/15 joel.c.mathias@gmail.com - cleaner use of NULLIF on WHEN MATCHED
 * @updated 01/31/20 joel.c.mathias@gmail.com - UNION ALL to VALUES
 *
 * 1) surrogate key  BIGINT NOT NULL IDENTITY(1,1)
 * 2) start date  DATETIME NOT NULL
 * 3) end date    DATETIME NULL (NULL indicates this row has the current values for the unique natural key)
 * 4) natural key ? NOT NULL
 * 5) ... elements
 *
 * INSERT INTO table
 * SELECT FROM MERGE OUTPUT (
 * MERGE INTO table
 * USING (generated template SQL for source column data)
 * ON (generates PK column for matching)
 * WHEN MATCHED set end date columns
 * WHEN NOT MATCHED BY TARGET (generates columns, except identity columns)
 * OUTPUT
 *
 */
USE database
GO
DECLARE @amehcs sysname
DECLARE @elbat sysname
DECLARE @id int
SELECT
	@id = object_id
,	@elbat = name
,	@amehcs = SCHEMA_NAME(schema_id)
FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND name = 'tablename';
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
		c1 AS teeQuence
	,	CASE c1 
			WHEN 1 THEN 'INSERT INTO ' + @amehcs + '.[' + @elbat + '] ('
			WHEN 2 THEN '  '  + name
			ELSE ', '  + name
		END AS teeSQL
	FROM crap
	UNION ALL
	SELECT
		c1 + 1000
	,	CASE c1 
			WHEN 1 THEN ') SELECT '
			WHEN 2 THEN '  DATEADD(dd, DATEDIFF(dd, 0, GETDATE()), 0)'
			WHEN 3 THEN ', NULL'
			ELSE ', ' + name
		END
	FROM crap
	UNION ALL
	SELECT
		c1 + 2000
	,	CASE c1 
			WHEN 1 THEN '    ISNULL(T1.' + name + ',0) AS ' + name
			ELSE '  , V1.' + name
		END
	FROM crap
	WHERE c1 = 1 OR c1 > 3
	UNION ALL
	SELECT
		c1 + 3000
	,	CASE c1 
			WHEN 2 THEN '  FROM ('
			WHEN 3 THEN '    SELECT'
			WHEN 4 THEN '      ' + name
			ELSE '    , ' + name
		END
	FROM (
		SELECT
			c1
		, 'expression ' + (CASE WHEN collation_name IS NULL THEN 'AS ' ELSE 'COLLATE ' + collation_name + ' AS ' END) + name AS name
		FROM crap
		WHERE c1 > 1
	) AS V1
	UNION ALL
	SELECT
		4004 - c1
	,	CASE c1 
			WHEN 1 THEN 'WHERE T1.' + name + ' IS NULL OR ('
			WHEN 3 THEN '  AND T1.' + name + ' IS NULL'
			WHEN 4 THEN 'LEFT JOIN ' + @amehcs + '.' + @elbat + ' AS T1 ON T1.' + name + ' = V1.' + name
		END
	FROM crap
	WHERE c1 IN(1,3,4)
	UNION ALL
	SELECT
		c1 + 4000
	,	CASE c1
			WHEN 5 THEN '       '
			ELSE '    OR '
		END +	CASE
			WHEN is_nullable = 1 THEN '((T1.'+name+' IS NULL AND V1.'+name+' IS NOT NULL) OR (NULLIF(T1.'+name+',V1.'+name+') IS NOT NULL))'
			ELSE '(NOT(V1.'+ name +' = T1.'+ name +'))'
		END
	FROM crap
	WHERE c1 > 4
	UNION ALL
	SELECT 
		4992 + c1
	,	CASE c1 
			WHEN 1 THEN 'ON (m.' + name + ' = u.' + name + ')'
			WHEN 2 THEN 'WHEN MATCHED THEN UPDATE'
			WHEN 3 THEN '  SET m.' + name + ' = DATEADD(dd, DATEDIFF(dd, 0, GETDATE()), -1)'
		END
	FROM crap
	WHERE c1 BETWEEN 1 AND 3
	UNION ALL
	SELECT
		c1 + 5000
	,	CASE c1 
			WHEN 1 THEN 'WHEN NOT MATCHED THEN INSERT ('
			WHEN 2 THEN '  ' + name
			ELSE ', ' + name
		END
	FROM crap
	UNION ALL
	SELECT
		c1 + 6000
	,	CASE c1 
			WHEN 1 THEN ') VALUES ('
			WHEN 2 THEN '  DATEADD(dd, DATEDIFF(dd, 0, GETDATE()), 0)'
			WHEN 3 THEN ', NULL'
			ELSE ', u.' + name
		END
	FROM crap
	UNION ALL
	SELECT
		c1 + 7000
	,	CASE c1 
			WHEN 1 THEN ')'
			WHEN 2 THEN 'OUTPUT'
			WHEN 3 THEN '  $action'
			ELSE ', U.' + name
		END
	FROM crap
	UNION ALL
	SELECT
		c1 + 8000
	,	CASE c1 
			WHEN 2 THEN ') AS i ('
			WHEN 3 THEN '  action'
			ELSE ', ' + name
		END
	FROM crap
	WHERE c1 > 1
	UNION ALL
	SELECT * FROM ( VALUES 
		( 1996,'FROM ( --- OUTPUT FROM MERGE' )
	,	( 1997,'MERGE INTO ' + @amehcs + '.' + @elbat + ' AS M' )
	,	( 1998,'USING (' )
	,	( 1999,'  SELECT' )
	,	( 3998,'    FROM dimension_source_rowset' )
	,	( 3999,'  ) AS V1' )
	,	( 4990,'  )' )
	,	( 4991,') AS U' )
	,	( 9000,')' )
	,	( 9001,'WHERE action = ''UPDATE''' )
	,	( 9003,'OPTION (MAXRECURSION 0);' )
	,	( 9004,'GO' )
	) Q1(teeQuence,teeSQL)
) AS V1
ORDER BY teeQuence;