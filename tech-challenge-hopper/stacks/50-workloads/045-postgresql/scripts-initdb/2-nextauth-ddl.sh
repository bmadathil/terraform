#!/bin/bash
set -e

export PGPASSWORD=$NEXTAUTH_DB_PASSWORD

psql -v ON_ERROR_STOP=1 --username "$NEXTAUTH_DB_USER" --dbname "$PGDATABASE" <<-EOSQL
  CREATE TABLE nextauth.user
  (
    user_name VARCHAR(25) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email_address VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    CONSTRAINT pk_user PRIMARY KEY (user_name),
    CONSTRAINT uq_user_email UNIQUE (email_address)
  );

  INSERT INTO nextauth.user(user_name, first_name, last_name, email_address, password)
  VALUES ('user1', 'User', 'One', 'user1@cvpcorp.com', '\$2a\$12\$DnXaYuKputtcigIHedtsqeuBHecxz9aKW8EG5/0jNUO59VB6YuWD.');

  CREATE TABLE nextauth.role
  (
    role_name VARCHAR(25) NOT NULL,
    role_description VARCHAR(255),
    CONSTRAINT pk_role PRIMARY KEY (role_name)
  );

  INSERT INTO nextauth.role(role_name, role_description)
  VALUES  ('User', 'A user of the system');

  CREATE TABLE nextauth.user_role
  (
    user_name VARCHAR(25) NOT NULL,
    role_name VARCHAR(25) NOT NULL,
    CONSTRAINT pk_user_role PRIMARY KEY (user_name, role_name),
    CONSTRAINT fk_user_role_user FOREIGN KEY (user_name)
      REFERENCES nextauth.user (user_name) MATCH SIMPLE,
    CONSTRAINT fk_user_role_role FOREIGN KEY (role_name)
      REFERENCES nextauth.role (role_name) MATCH SIMPLE
  );

  INSERT INTO nextauth.user_role(user_name, role_name)
  VALUES  ('user1', 'User');
EOSQL
