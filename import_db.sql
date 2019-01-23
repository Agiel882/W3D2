PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname TEXT NOT NULL,
  lname TEXT NOT NULL

);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  author_id INTEGER NOT NULL,

  FOREIGN KEY (author_id) REFERENCES users(id)

);

CREATE TABLE question_follows (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)

);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  body TEXT NOT NULL,
  question_id INTEGER NOT NULL,
  parent_id INTEGER,
  user_id INTEGER NOT NULL, 

  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (parent_id) REFERENCES replies(id),
  FOREIGN KEY (user_id) REFERENCES users(id)

);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)

);

INSERT INTO 
  users (fname, lname)
VALUES
  ('John', 'Doe'),
  ('Alice', 'Smith');

INSERT INTO
  questions (title, body, author_id)
VALUES
  ("Birthday Question", "When is your birthday?", (SELECT id FROM users WHERE fname = 'Alice')),
  ("Food Question", "What is your favorite meal?", (SELECT id FROM users WHERE lname = 'Doe'));

INSERT INTO
  question_follows(user_id, question_id)
VALUES
  ((SELECT id FROM users WHERE fname = 'John'), (SELECT id FROM questions WHERE title = "Food Question")),
  ((SELECT id FROM users WHERE lname = 'Smith'), (SELECT id FROM questions WHERE title = "Birthday Question"));

INSERT INTO
  replies(body, question_id, parent_id, user_id)
VALUES
  ("January 1st", (SELECT id FROM questions WHERE title = "Birthday Question"), NULL, (SELECT id FROM users WHERE fname = 'John')),
  ("Hotdogs", (SELECT id FROM questions WHERE title = "Food Question"), NULL, (SELECT id FROM users WHERE fname = 'Alice'));

INSERT INTO
  question_likes (user_id, question_id)
VALUES
  ((SELECT id FROM users WHERE fname = 'John'), (SELECT id FROM questions WHERE title = "Food Question")),
  ((SELECT id FROM users WHERE lname = 'Smith'), (SELECT id FROM questions WHERE title = "Birthday Question"));



