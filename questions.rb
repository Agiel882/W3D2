require 'sqlite3'
require 'singleton'
require 'active_support/inflector'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class ModelBase

  def self.find_by_id(id)
    data = QuestionsDatabase.instance.execute(<<~SQL, id)
      SELECT 
        *
      FROM
        '#{self.table}'
      WHERE
        id = ?
    SQL
    return nil if data.empty?
    question = self.new(data[0])
  end

   def self.all
    data = QuestionsDatabase.instance.execute("SELECT * FROM #{self.table}")
    data.map {|datum| self.new(datum)}
  end

  def self.table
    self.to_s.tableize
  end

  def save
    raise "#{self} already in database" if @id
    vars = []
    self.instance_variables[1..-1].map{|col| (col.to_s[1..-1]).to_sym}.each do |var|
      vars << self.send(var)
    end

    QuestionsDatabase.instance.execute(<<~SQL, *vars)
      INSERT INTO
        '#{self.class.table}' (title, body, author_id)
      VALUES
        (#{("?" * (vars.length - 1)).split("").join(", ")})
    SQL
    @id = QuestionsDatabase.instance.last_insert_row_id
  end
end

class Question < ModelBase
  attr_accessor :id, :title, :body, :author_id

  def self.find_by_author_id(author_id)
    data = QuestionsDatabase.instance.execute(<<~SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        author_id = ?
    SQL
    data.map {|datum| Question.new(datum) }
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end


  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
  end

 

  def update
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<~SQL, @title, @body, @author_id, @id)
      UPDATE
        questions
      SET
        title = ?, body = ?, author_id = ?
      WHERE
        id = ?
    SQL
  end

  def author
    data = QuestionsDatabase.instance.execute(<<~SQL, author_id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL
    data.map {|datum| User.new(datum)}
  end

  def replies
    Reply.find_by_question_id(id)
  end

  def followers
    QuestionFollow.followers_for_question_id(id)
  end

  def likers
    QuestionLike.likers_for_question_id(id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(id)
  end
end

class User < ModelBase
  attr_accessor :id, :fname, :lname

  def self.find_by_name(fname, lname)
    data = QuestionsDatabase.instance.execute(<<~SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL
    data.map {|datum| User.new(datum)}
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def create
    raise "#{self} already in database" if @id
    QuestionsDatabase.instance.execute(<<~SQL,@fname,@lname)
      INSERT INTO
        users (fname,lname)
      VALUES
        (?, ?)
    SQL
    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<~SQL, @fname, @lname, @id)
      UPDATE
        users
      SET
        fname = ?, lname = ?
      WHERE
        id = ?
    SQL
  end

  def authored_questions
    Question.find_by_author_id(id)
  end

  def authored_replies
    Reply.find_by_user_id(id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(id)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(id)
  end

  def average_karma
    data = QuestionsDatabase.instance.execute(<<~SQL, id)
      SELECT
        (CAST(COUNT(question_likes.question_id) AS FLOAT) / count(DISTINCT(questions.id))) AS avg_karma
      FROM 
        questions
      LEFT JOIN question_likes ON question_likes.question_id = questions.id
      WHERE
        questions.author_id = ?
    SQL
    data[0]["avg_karma"]
  end
end

class Reply < ModelBase
  attr_accessor :id, :body, :question_id, :parent_id, :user_id

  def self.find_by_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<~SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL
    data.map {|datum| Reply.new(datum) }
  end


  def self.find_by_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<~SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        question_id = ?
    SQL
    data.map {|datum| Reply.new(datum) }
  end

  def initialize(options)
    @id = options['id']
    @body = options['body']
    @question_id = options['question_id']
    @parent_id = options['parent_id']
    @user_id = options['user_id']
  end

  def create
    raise "#{self} already in database" if @id
    QuestionsDatabase.instance.execute(<<~SQL,@body,@question_id,@parent_id,@user_id)
      INSERT INTO
        replies (body, question_id, parent_id, user_id)
      VALUES
        (?, ?, ?, ?)
    SQL
    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<~SQL, @body,@question_id,@parent_id,@user_id, @id)
      UPDATE
        replies
      SET
        body = ?, question_id = ?, parent_id = ?, user_id = ?
      WHERE
        id = ?
    SQL
  end

  def author
    data = QuestionsDatabase.instance.execute(<<~SQL, user_id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL
    data.map {|datum| User.new(datum)}
  end

  def question
    data = QuestionsDatabase.instance.execute(<<~SQL, question_id)
      SELECT
        *
      FROM
        questions
      WHERE
        id = ?
    SQL
    data.map {|datum| Question.new(datum)}
  end

  def parent_reply
    Reply.find_by_id(parent_id)
  end

  def child_replies
    data = QuestionsDatabase.instance.execute(<<~SQL, id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_id = ?
    SQL
    data.map {|datum| Reply.new(datum) }
  end
end

class QuestionFollow < ModelBase
  attr_accessor :id, :question_id, :user_id

  def self.followers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<~SQL, question_id)
      SELECT
        users.id, users.fname, users.lname
      FROM
        questions
      JOIN question_follows ON question_follows.question_id = questions.id
      JOIN users ON question_follows.user_id = users.id
      WHERE
        questions.id = ?
    SQL
    data.map {|datum| User.new(datum)}
  end

  def self.followed_questions_for_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<~SQL, user_id)
      SELECT
        questions.id, questions.title, questions.body, questions.author_id
      FROM
        users
      JOIN question_follows ON question_follows.user_id = users.id
      JOIN questions ON question_follows.question_id = questions.id
      WHERE
        users.id = ?
    SQL
    data.map {|datum| Question.new(datum)}
  end

  def self.most_followed_questions(n)
    data = QuestionsDatabase.instance.execute(<<~SQL, n)
      SELECT
        questions.id, questions.title, questions.body, questions.author_id
      FROM
        question_follows
      JOIN questions ON question_follows.question_id = questions.id
      GROUP BY
        question_follows.question_id
      ORDER BY
        COUNT(question_follows.question_id) DESC
      LIMIT
        ?
    SQL
    data.map {|datum| Question.new(datum)}
  end

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @user_id = options['user_id']
  end

  def create
    raise "#{self} already in database" if @id
    QuestionsDatabase.instance.execute(<<~SQL,@user_id,@question_id)
      INSERT INTO
        question_follows (user_id, question_id)
      VALUES
        (?, ?)
    SQL
    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<~SQL,@user_id,@question_id, @id)
      UPDATE
        question_follows
      SET
        user_id = ?, question_id = ?
      WHERE
        id = ?
    SQL
  end
end

class QuestionLike < ModelBase
  attr_accessor :id, :question_id, :user_id

  def self.likers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<~SQL, question_id)
      SELECT
        users.id, users.fname, users.lname
      FROM
        questions
      JOIN question_likes ON question_likes.question_id = questions.id
      JOIN users ON question_likes.user_id = users.id
      WHERE
        questions.id = ?
    SQL
    data.map {|datum| User.new(datum)}
  end

    def self.num_likes_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<~SQL, question_id)
      SELECT
        COUNT(question_likes.user_id) AS num_likes
      FROM
        question_likes
      WHERE
        question_id = ?
    SQL
    data[0]["num_likes"]
  end

  def self.liked_questions_for_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<~SQL, user_id)
      SELECT
        questions.id, questions.title, questions.body, questions.author_id
      FROM
        users
      JOIN question_likes ON question_likes.user_id = users.id
      JOIN questions ON question_likes.question_id = questions.id
      WHERE
        users.id = ?
    SQL
    data.map {|datum| Question.new(datum)}
  end

  def self.most_liked_questions(n)
    data = QuestionsDatabase.instance.execute(<<~SQL, n)
      SELECT
        questions.id, questions.title, questions.body, questions.author_id
      FROM
        question_likes
      JOIN questions ON question_likes.question_id = questions.id
      GROUP BY
        question_likes.question_id
      ORDER BY
        COUNT(question_likes.question_id) DESC
      LIMIT
        ?
    SQL
    data.map {|datum| Question.new(datum)}
  end

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @user_id = options['user_id']
  end

  def create
    raise "#{self} already in database" if @id
    QuestionsDatabase.instance.execute(<<~SQL,@user_id,@question_id)
      INSERT INTO
        question_likes (user_id, question_id)
      VALUES
        (?, ?)
    SQL
    @id = QuestionsDatabase.instance.last_insert_row_id
  end

  def update
    raise "#{self} not in database" unless @id
    QuestionsDatabase.instance.execute(<<~SQL,@user_id,@question_id, @id)
      UPDATE
        question_likes
      SET
        user_id = ?, question_id = ?
      WHERE
        id = ?
    SQL
  end
end