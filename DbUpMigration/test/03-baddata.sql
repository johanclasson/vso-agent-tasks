--BEGIN TRY
--    BEGIN TRANSACTION 

		INSERT INTO Person (Id,Name)
		VALUES (2, 'Doe');

		INSERT INTO Person (Id,Name)
		VALUES (1, 'John');

--    COMMIT
--END TRY
--BEGIN CATCH
--    IF @@TRANCOUNT > 0
--        ROLLBACK
--END CATCH
