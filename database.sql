CREATE TABLE contact ( 
	contact_id           int NOT NULL   IDENTITY,
	contact_fname        varchar(100) NOT NULL   ,
	contact_mname        varchar(100)    ,
	contact_lname        varchar(100) NOT NULL   ,
	contact_email        varchar(100)    ,
	contact_phone        varchar(20)    ,
	contact_street_address1 varchar(100)    ,
	contact_street_address2 varchar(100)    ,
	contact_city         varchar(50)    ,
	contact_state        varchar(50)    ,
	contact_postal_code  varchar(10)    ,
	contact_country      varchar(50)    ,
	contact_linkedin_id  varbinary(100) NOT NULL   ,
	CONSTRAINT Pk_Contacts PRIMARY KEY ( contact_id ),
	CONSTRAINT Uk_LinkedIn_ID UNIQUE ( contact_linkedin_id ) 
 );

ALTER TABLE contact ADD CONSTRAINT Ck_email_phone CHECK ( contact_phone IS NOT NULL OR contact_email IS NOT NULL );

CREATE TABLE users ( 
	users_id             int NOT NULL   IDENTITY,
	users_name           varchar(100) NOT NULL   ,
	users_contact_id     int NOT NULL   ,
	users_linkedin_oauth nvarchar(200) NOT NULL   ,
	CONSTRAINT Pk_user PRIMARY KEY ( users_id )
 );

CREATE TABLE job ( 
	job_id               int NOT NULL   IDENTITY,
	job_title            varchar(150) NOT NULL   ,
	job_description      text NOT NULL   ,
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

CREATE TABLE user_contacts ( 
	user_contacts_id     int NOT NULL   IDENTITY,
	user_conacts_user_id int NOT NULL   ,
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
        contact.contact_city AS City,
        contact.contact_state AS State,
        contact.contact_id AS ContactID,
        contact.contact_linkedin_id AS LinkedInID
    FROM contact
    WHERE ContactID IN (SELECT user_contacts_contact_id FROM user_contacts WHERE user_contacts_user_id = @UserID);

CREATE FUNCTION GetUserJobs (@UserID int)
RETURNS TABLE
RETURN
    SELECT job.job_id AS JobID,
        job.job_title AS Title,
        job.job_description AS Description,
        job.job_user_id AS UserID,
        job.job_date_added AS DateAdded,
        job.job_date_closed AS DateClosed,
        GetNameForContact(referral.contact_id) AS ReferredApplicant,
        GetNameForContact(users.users_contact_id) AS Referrer
    FROM job
    LEFT JOIN referral ON referral.referral_job_id=job.job_id
    INNER JOIN users ON users.users_id=job.job_user_id
    WHERE JobUserID = @UserID;;

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
    @FirstName varchar(100),
    @MiddleName varchar(100),
    @LastName varchar(100),
    @Email varchar(100),
    @Phone varchar(20),
    @Address1 varchar(100) = '',
    @Address2 varchar(100) = '',
    @City varchar(50) = '',
    @State varchar(50) = '',
    @PostalCode varchar(10) = '',
    @Country varchar(50) = 'United States'
AS
    MERGE INTO contact
    USING
        (SELECT @LinkedInID AS LinkedInID) AS SRC
            ON (contact.contact_linkedin_id = SRC.LinkedInID)
    WHEN MATCHED THEN
        UPDATE SET contact_fname = @FirstName,
        contact_mname = @MiddleName,
        contact_lname = @LastName,
        contact_email = @Email,
        contact_phone = @Phone,
        contact_street_address1 = @Address1,
        contact_street_address2 = @Address2,
        contact_city = @City,
        contact_state = @State,
        contact_postal_code = @PostalCode,
        contact_country = @Country
    WHEN NOT MATCHED THEN
        INSERT (contact_fname, contact_mname, contact_lname, contact_email, contact_phone, contact_street_address1, contact_street_address2, contact_city, contact_state, contact_postal_code, contact_country)
            VALUES (@FirstName, @MiddleName, @LastName, @Email, @Phone, @Address1, @Address2, @City, @State, @PostalCode, @Country);;

CREATE PROCEDURE UpdateUserContacts
    @ContactID int,
    @UserID int
AS
    MERGE INTO user_contacts
    USING
        (SELECT @ContactID AS ContactID, @UserID AS UserID) AS SRC
            ON (user_contacts.user_contact_contact_id = SRC.ContactID AND user_contacts.user_contact_user_id = SRC.UserID)
    WHEN MATCHED THEN
        UPDATE SET user_contact_contact_id=@ContactID, user_contacts_user_id=@UserID
    WHEN NOT MATCHED THEN
        INSERT (user_contacts_contact_id, user_contacts_user_id)
            VALUES (@ContactID, @UserID);;

ALTER TABLE job ADD CONSTRAINT fk_job_users FOREIGN KEY ( job_user_id ) REFERENCES users( users_id ) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE referral ADD CONSTRAINT fk_referral_user_id FOREIGN KEY ( referral_id ) REFERENCES users( users_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE referral ADD CONSTRAINT fk_referral_contact_id FOREIGN KEY ( referral_id ) REFERENCES contact( contact_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE referral ADD CONSTRAINT fk_referral_job FOREIGN KEY ( referral_id ) REFERENCES job( job_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE user_contacts ADD CONSTRAINT fk_user_contacts_user FOREIGN KEY ( user_contacts_id ) REFERENCES users( users_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE user_contacts ADD CONSTRAINT fk_user_contacts_contact FOREIGN KEY ( user_contacts_id ) REFERENCES contact( contact_id ) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE users ADD CONSTRAINT fk_user_contact FOREIGN KEY ( users_id ) REFERENCES contact( contact_id ) ON DELETE SET NULL ON UPDATE CASCADE;

