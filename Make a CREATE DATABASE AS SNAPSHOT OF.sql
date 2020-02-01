/**
 * Make a CREATE DATABASE AS SNAPSHOT OF - T-SQL to generate T-SQL to create a snapshot of the current SQL Server database.
 *
 * @author  joelcmathias@gmail.com (Joel Mathias)
 * @author  jmathias@cscc.edu (Joel Mathias)
 * @created 03/24/16
 * @updated 03/27/17 joelcmathias@gmail.com - fixed RANK() for databases with only primary file group (i.e. most of them)
 * @updated 12/08/17 jmathias@cscc.edu - refactored for SSMS 2017 formatting and support
 * @updated 01/31/20 joelcmathias@gmail.com - changed use of high ASCII with @?@ due to issues with collations
 *
 * Requires a version of SQL Server that supports database snapshots like Enterprise Edition, Developer Edition
 *
 * Tested and verified on:
 * - SQL Server 2008 R2 - 03/24/2016
 * - SQL Server 2012 -
 * - SQL Server 2014 - 09/12/2016 5:24:05 PM
 * - SQL Server 2017 - 12/8/2017 1:49:03 PM
 *
 * Usage:
 * - USE database_to_create_snapshot_for
 * - run script
 * - copy / paste
 *
 */
DECLARE
	@SnapSuffix	NVARCHAR(254) = N'Snapshot' -- PatchSnapshot -- Snapshot -- TestingSnapshot -- SnapshotYYMM
SELECT REPLACE(REPLACE(CASE
	WHEN wor = 1 THEN '  '+lqs
	WHEN wor BETWEEN 2 AND 899 THEN ', '+lqs
	ELSE lqs
END,'@D@',DB_NAME()),'@S@',@SnapSuffix) AS TeeSQL
FROM (
	SELECT
		'( NAME = '+name+', FILENAME = '''+LEFT(physical_name,LEN(physical_name)-4)+'_@S@.ss'' )' AS lqs
	,	RANK() OVER(ORDER BY data_space_id, name) AS wor
	FROM sys.database_files
	WHERE type = 0
	UNION ALL
	SELECT lqs,wor
	FROM ( VALUES
		(0,'CREATE DATABASE [@D@_@S@] ON')
	,	(990,'AS')
	,	(991,'SNAPSHOT OF [@D@];')
	,	(992,'GO')
	,	(999,'GO')
	,	(1000,'/* RESTORE T-SQL')
	,	(1001,'USE master')
	,	(1002,'GO')
	,	(1003,'ALTER DATABASE [@D@] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;')
	,	(1004,'GO')
	,	(1005,'RESTORE DATABASE [@D@] FROM DATABASE_SNAPSHOT = ''@D@_@S@'';')
	,	(1006,'GO')
	,	(1007,'*/ ')
	,	(1008,'/* DROP SNAPSHOT T-SQL')
	,	(1009,'USE master')
	,	(1010,'GO')
	,	(1011,'DROP DATABASE [@D@_@S@];')
	,	(1012,'GO')
	,	(1013,'*/')
	) Q1(wor,lqs)
	UNION ALL
	SELECT 'PRINT ''Snapshot of Database @D@ created as @D@_@S@ on '+@@SERVERNAME+' at '+CONVERT(VARCHAR(16),GETDATE(),121)+'''',998
) AS Q
ORDER BY wor;
GO