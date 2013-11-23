CREATE TABLE contact ( 
	contact_id           int NOT NULL   IDENTITY,
	contact_fname        varchar(100) NOT NULL   ,
	contact_lname        varchar(100) NOT NULL   ,
	contact_job_title    varchar(150) NOT NULL   ,
	contact_email        varchar(100)    ,
	contact_phone        varchar(20)    ,
	contact_city         varchar(50)    ,
	contact_state        varchar(50)    ,
	contact_linkedin_id  varchar(100) NOT NULL   ,
	contact_linkedin_url varchar(200)    ,
	CONSTRAINT Pk_Contacts PRIMARY KEY ( contact_id ),
	CONSTRAINT Uk_LinkedIn_ID UNIQUE ( contact_linkedin_id ) ,
	CONSTRAINT Uk_LinkedIn_URL UNIQUE ( contact_linkedin_url ) 
 );

ALTER TABLE contact ADD CONSTRAINT Ck_email_phone CHECK ( contact_phone IS NOT NULL OR contact_email IS NOT NULL );

CREATE TABLE users ( 
	users_id             int NOT NULL   IDENTITY,
	users_name           varchar(100) NOT NULL   ,
	users_contact_id     int NOT NULL   ,
	users_linkedin_oauth varchar(200) NOT NULL   ,
	CONSTRAINT Pk_user PRIMARY KEY ( users_id )
 );

CREATE TABLE job ( 
	job_id               int NOT NULL   IDENTITY,
	job_company          varchar(100) NOT NULL   ,
	job_title            varchar(150) NOT NULL   ,
	job_url              text NOT NULL   ,
	job_user_id          int NOT NULL   ,
	job_date_added       datetime  CONSTRAINT defo_job_date_added DEFAULT getdate()  ,
	job_date_closed      datetime    ,
	CONSTRAINT Pk_job PRIMARY KEY ( job_id )
 );

CREATE INDEX idx_job ON job ( job_user_id );

CREATE TABLE referral ( 
	referral_id          int NOT NULL   IDENTITY,
	referral_user_id     int NOT NULL   ,
	referral_contact_id  int NOT NULL   ,
	referral_job_id      int NOT NULL   ,
	referral_date        datetime NOT NULL CONSTRAINT defo_referral_date DEFAULT getdate()  ,
	CONSTRAINT Pk_referral PRIMARY KEY ( referral_id )
 );

CREATE INDEX idx_referral ON referral ( referral_contact_id );

CREATE INDEX idx_referral_0 ON referral ( referral_job_id );

CREATE INDEX idx_referral_1 ON referral ( referral_user_id );

CREATE TABLE user_contacts ( 
	user_contacts_id     int NOT NULL   IDENTITY,
	user_contacts_user_id int NOT NULL   ,
	user_contacts_contact_id int NOT NULL   ,
	CONSTRAINT Pk_user_contacts PRIMARY KEY ( user_contacts_id )
 );

CREATE FUNCTION GetNameForContact (@ContactID int)
RETURNS varchar(200)
BEGIN
    DECLARE @CName varchar(200);
    SELECT @CName = CONCAT(contact.contact_fname, ' ', contact.contact_lname)
    FROM contact
    WHERE contact.contact_id = @ContactID;
    RETURN @CName
END;

CREATE FUNCTION GetUserContacts (@UserID int)
RETURNS TABLE
RETURN
    SELECT GetNameForContact(contact.contact_id) AS ContactName,
        contact.contact_job_title AS JobTitle,
        contact.contact_city AS City,
        contact.contact_state AS State,
        contact.contact_id AS ContactID,
        contact.contact_linkedin_id AS LinkedInID,
        contact.contact_linkedin_url AS LinkedInURL
    FROM contact
    WHERE contact.contact_id IN (SELECT user_contacts_contact_id FROM user_contacts WHERE user_contacts_user_id = @UserID);

CREATE FUNCTION GetUserJobs (@UserID int, @MyPostings int = 1)
RETURNS @results TABLE (JobID int, Company varchar(100), Title varchar(150), URL text, UserID int, DateAdded datetime, DateClosed datetime, ReferredApplicant varchar(200), Referrer varchar(200))
AS BEGIN
IF @MyPostings = 1
BEGIN
    INSERT @results (JobID, Company, Title, URL, UserID, DateAdded, DateClosed, ReferredApplicant, Referrer) SELECT job.job_id AS JobID,
        job.job_company AS Company,
        job.job_title AS Title,
        job.job_url AS URL,
        job.job_user_id AS UserID,
        job.job_date_added AS DateAdded,
        job.job_date_closed AS DateClosed,
        dbo.GetNameForContact(referral.referral_contact_id) AS ReferredApplicant,
        dbo.GetNameForContact(users.users_contact_id) AS Referrer
    FROM job
    LEFT JOIN referral ON referral.referral_job_id=job.job_id
    INNER JOIN users ON users.users_id=job.job_user_id
    WHERE job.job_user_id = @UserID
    AND (job.job_date_closed > GetDate() OR job.job_date_closed IS NULL)
END
ELSE
BEGIN
    INSERT @results (JobID, Company, Title, URL, UserID, DateAdded, DateClosed, ReferredApplicant, Referrer) SELECT job.job_id AS JobID,
        job.job_company AS Company,
        job.job_title AS Title,
        job.job_url AS URL,
        job.job_user_id AS UserID,
        job.job_date_added AS DateAdded,
        job.job_date_closed AS DateClosed,
        dbo.GetNameForContact(referral.referral_contact_id) AS ReferredApplicant,
        dbo.GetNameForContact(users.users_contact_id) AS Referrer
    FROM job
    LEFT JOIN referral ON referral.referral_job_id=job.job_id
    INNER JOIN users ON users.users_id=job.job_user_id
    WHERE job.job_user_id IN (SELECT users_id FROM users WHERE users_contact_id IN (SELECT user_contacts_contact_id FROM user_contacts WHERE user_contacts_user_id = @UserID))
    AND (job.job_date_closed > GetDate() OR job.job_date_closed IS NULL)
END
RETURN
END;

CREATE FUNCTION UserLogin (@LinkedInOAuth varchar(200), @LinkedInID varchar(100))
RETURNS bit
BEGIN
    DECLARE @UserID int;
    DECLARE @ContactID int;
    DECLARE @FirstName varchar(100);
    DECLARE @LastName varchar(100);
    SELECT @UserID = users.users_id FROM users WHERE users_linkedin_oauth = @LinkedInOAuth;
    IF(@@ROWCOUNT = 0)
    BEGIN
        SELECT @ContactID = contact.contact_id, @FirstName = contact.contact_fname, @LastName = contact.contact_lname FROM contact WHERE contact_linkedin_id = @LinkedInID;
        IF(@@ROWCOUNT = 0) 
            RETURN 0;
        ELSE
        BEGIN
			DECLARE @Username varchar(100) = CONCAT(@FirstName, @LastName, @LinkedInID);
            EXEC dbo.UpdateUser @Username, @ContactID, @LinkedInOAuth; 
            RETURN 1;
        END
    END
    RETURN 1;
END;

CREATE PROCEDURE AddReferral
	@Referrer int,
	@Referral int,
	@Job int
AS
    MERGE INTO referral
    USING
        (SELECT @Referrer AS ReferrerID, @Referral AS ReferralID, @Job as JobID) AS SRC
            ON (referral.referral_user_id = SRC.ReferrerID AND referral.referral_contact_id = SRC.ReferralID AND referral.referral_job_id = SRC.jobID)
    WHEN MATCHED THEN
        UPDATE SET referral_user_id=@Referrer, referral_contact_id=@Referral, referral_job_id=@Job
    WHEN NOT MATCHED THEN
        INSERT (referral_user_id, referral_contact_id, referral_job_id)
            VALUES (@Referrer, @Referral, @Job);;

CREATE PROCEDURE CloseJobListing
    @JobID int
AS
    UPDATE job SET job_date_closed = GetDate()
    WHERE job_id = @JobID;;

CREATE PROCEDURE DropReferral
	@Referrer int,
	@Referral int,
	@Job int
AS
    DELETE FROM referral
        WHERE referral.referral_user_id = @Referrer
        AND referral.referral_contact_id = @Referral
        AND referral.referral_job_id = @Job;

CREATE PROCEDURE UpdateContact
    @LinkedInID varchar(100),
    @LinkedInURL varchar(200),
    @FirstName varchar(100),
    @LastName varchar(100),
    @Email varchar(100) = '',
    @Phone varchar(20) = '',
    @City varchar(50) = '',
    @State varchar(50) = ''
AS
    MERGE INTO contact
    USING
        (SELECT @LinkedInID AS LinkedInID) AS SRC
            ON (contact.contact_linkedin_id = SRC.LinkedInID)
    WHEN MATCHED THEN
        UPDATE SET contact_fname = @FirstName,
        contact_lname = @LastName,
        contact_email = @Email,
        contact_phone = @Phone,
        contact_city = @City,  
        contact_state = @State,
        contact_linkedin_url = @LinkedInURL
    WHEN NOT MATCHED THEN
        INSERT (contact_fname, contact_lname, contact_email, contact_phone, contact_city, contact_state, contact_linkedin_url)
            VALUES (@FirstName, @LastName, @Email, @Phone, @City, @State, @LinkedInURL);;

CREATE PROCEDURE UpdateJobListing
    @Company varchar(100),
    @Title varchar(150),
    @URL text,
    @JobPoster int,
    @JobID int = NULL
AS
    MERGE INTO job
    USING
        (SELECT @JobID AS JobID) AS SRC
            ON (job.job_id = SRC.JobID)
    WHEN MATCHED THEN
        UPDATE SET job_company = @Company,
        job_title = @Title,
        job_url = @URL,
        job_user_id = @JobPoster
    WHEN NOT MATCHED THEN
        INSERT (job_company, job_title, job_url, job_user_id, job_date_added)
            VALUES (@Company, @Title, @URL, @JobPoster, GetDate());;

CREATE PROCEDURE UpdateUser
    @Username varchar(100),
    @ContactID int,
    @LinkedInOAuth varchar(200),
    @UserID int = NULL
AS
        MERGE INTO users
        USING
            (SELECT @UserID AS UserID) AS SRC
                ON (users.users_id = SRC.UserID)
        WHEN MATCHED THEN
            UPDATE SET users_name = @Username,
            users_contact_id = @ContactID,
            users_linkedin_oauth = @LinkedInOAuth
        WHEN NOT MATCHED THEN
            INSERT (users_name, users_contact_id, users_linkedin_oauth)
                VALUES (@Username, @ContactID, @LinkedInOAuth);;

CREATE PROCEDURE UpdateUserContacts
    @ContactID int,
    @UserID int
AS
    MERGE INTO user_contacts
    USING
        (SELECT @ContactID AS ContactID, @UserID AS UserID) AS SRC
            ON (user_contacts.user_contacts_contact_id = SRC.ContactID AND user_contacts.user_contacts_user_id = SRC.UserID)
    WHEN MATCHED THEN
        UPDATE SET user_contacts_contact_id=@ContactID, user_contacts_user_id=@UserID
    WHEN NOT MATCHED THEN
        INSERT (user_contacts_contact_id, user_contacts_user_id)
            VALUES (@ContactID, @UserID);;

ALTER TABLE job ADD CONSTRAINT fk_job_users FOREIGN KEY ( job_user_id ) REFERENCES users( users_id ) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE referral ADD CONSTRAINT fk_referral_contact FOREIGN KEY ( referral_contact_id ) REFERENCES contact( contact_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE referral ADD CONSTRAINT fk_referral_job FOREIGN KEY ( referral_job_id ) REFERENCES job( job_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE referral ADD CONSTRAINT fk_referral_users FOREIGN KEY ( referral_user_id ) REFERENCES users( users_id ) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE user_contacts ADD CONSTRAINT fk_user_contacts_user FOREIGN KEY ( user_contacts_id ) REFERENCES users( users_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE user_contacts ADD CONSTRAINT fk_user_contacts_contact FOREIGN KEY ( user_contacts_id ) REFERENCES contact( contact_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE users ADD CONSTRAINT fk_user_contact FOREIGN KEY ( users_id ) REFERENCES contact( contact_id ) ON DELETE SET NULL ON UPDATE CASCADE;

