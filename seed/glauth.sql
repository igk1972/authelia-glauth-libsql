-- Seed data for the glauth LDAP directory (sqld namespace: glauth).
--
-- glauth SQL backends are READ-ONLY over LDAP, so the directory is populated here
-- directly via SQL. This file is self-contained and idempotent: it (re)creates the
-- schema (IF NOT EXISTS, matching glauth's embed CreateSchema), clears the tables,
-- then inserts test data. glauth's own CreateSchema on startup is then a no-op.
--
-- Test password for both users below is "password":
--   sha256("password") = 5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8

-- --- schema (mirrors glauth embed backend) ---
CREATE TABLE IF NOT EXISTS users (
	id INTEGER PRIMARY KEY,
	name TEXT NOT NULL,
	uidnumber INTEGER NOT NULL,
	primarygroup INTEGER NOT NULL,
	othergroups TEXT DEFAULT '',
	givenname TEXT DEFAULT '',
	sn TEXT DEFAULT '',
	mail TEXT DEFAULT '',
	loginshell TEXT DEFAULT '',
	homedirectory TEXT DEFAULT '',
	disabled SMALLINT DEFAULT 0,
	passsha256 TEXT DEFAULT '',
	passbcrypt TEXT DEFAULT '',
	otpsecret TEXT DEFAULT '',
	yubikey TEXT DEFAULT '',
	sshkeys TEXT DEFAULT '',
	custattr TEXT DEFAULT '{}');
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_name on users(name);
CREATE TABLE IF NOT EXISTS ldapgroups (id INTEGER PRIMARY KEY, name TEXT NOT NULL, gidnumber INTEGER NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS idx_group_name on ldapgroups(name);
CREATE TABLE IF NOT EXISTS includegroups (id INTEGER PRIMARY KEY, parentgroupid INTEGER NOT NULL, includegroupid INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS capabilities (id INTEGER PRIMARY KEY, userid INTEGER NOT NULL, action TEXT NOT NULL, object TEXT NOT NULL);

-- --- reset ---
DELETE FROM capabilities;
DELETE FROM includegroups;
DELETE FROM users;
DELETE FROM ldapgroups;

-- --- groups ---
INSERT INTO ldapgroups (name, gidnumber) VALUES ('admins', 5501);
INSERT INTO ldapgroups (name, gidnumber) VALUES ('users', 5502);

-- --- users (password = "password") ---
INSERT INTO users
  (name, uidnumber, primarygroup, othergroups, givenname, sn, mail,
   loginshell, homedirectory, disabled, passsha256, custattr)
VALUES
  ('john', 5001, 5501, '5502', 'John', 'Doe', 'john@example.com',
   '/bin/bash', '/home/john', 0,
   '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', '{}');
INSERT INTO users
  (name, uidnumber, primarygroup, othergroups, givenname, sn, mail,
   loginshell, homedirectory, disabled, passsha256, custattr)
VALUES
  ('jane', 5002, 5502, '', 'Jane', 'Roe', 'jane@example.com',
   '/bin/bash', '/home/jane', 0,
   '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', '{}');

-- --- capabilities: admins can search the whole tree ---
INSERT INTO capabilities (userid, action, object) VALUES (5001, 'search', '*');
