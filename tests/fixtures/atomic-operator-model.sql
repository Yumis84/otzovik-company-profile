-- DISPOSABLE TEST FIXTURE ONLY. Never apply to hosted or production.
CREATE SCHEMA synthetic_operator;
CREATE TABLE synthetic_operator.subjects(id uuid PRIMARY KEY, identity_id uuid NOT NULL UNIQUE, epoch bigint NOT NULL DEFAULT 0 CHECK(epoch>=0), active boolean NOT NULL DEFAULT true, is_admin boolean NOT NULL DEFAULT false);
CREATE TABLE synthetic_operator.consumptions(jti uuid PRIMARY KEY, subject_id uuid NOT NULL, action text NOT NULL, target uuid NOT NULL, outcome text NOT NULL CHECK(outcome IN ('done','rejected')));
CREATE TABLE synthetic_operator.actions(jti uuid PRIMARY KEY REFERENCES synthetic_operator.consumptions(jti), action text NOT NULL, target uuid NOT NULL);
CREATE TABLE synthetic_operator.revoked(jti uuid PRIMARY KEY, subject_id uuid NOT NULL);
CREATE TABLE synthetic_operator.support_cases(id uuid PRIMARY KEY, subject_id uuid NOT NULL, requester uuid NOT NULL, CHECK(subject_id<>requester));
CREATE TABLE synthetic_operator.used_assertions(jti uuid PRIMARY KEY, reviewer uuid NOT NULL, case_id uuid NOT NULL);
CREATE TABLE synthetic_operator.reviews(case_id uuid NOT NULL REFERENCES synthetic_operator.support_cases(id), reviewer uuid NOT NULL, identity_id uuid NOT NULL, mfa_at bigint NOT NULL, epoch bigint NOT NULL, reviewed_at bigint NOT NULL, PRIMARY KEY(case_id,reviewer), UNIQUE(case_id,identity_id));
CREATE TABLE synthetic_operator.audit(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, event text NOT NULL, jti uuid, subject_id uuid, reviewer uuid, mfa_at bigint, recorded_at bigint NOT NULL);
