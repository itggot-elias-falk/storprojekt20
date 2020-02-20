require "sqlite3"
require "bcrypt"

def db()
    db = SQLite3::Database.new("db/cloud_db.db")
    db.results_as_hash = true
    return db
end

def validate_password(email, password)
    password_for_email = db.execute("SELECT password_digest FROM users WHERE email = ?", email)[0]["password_digest"]

    if BCrypt::Password.new(password_for_email) != password
        return False
    else
        return True
    end
end

def validate_email(email)
    if db.execute("SELECT email FROM users WHERE email = ?", email).empty?
        return False
    else
        return True
    end
end

def get_user_data(email)
    user_id = db.execute("SELECT user_id FROM users WHERE email = ?", email)[0]["user_id"]
    username = db.execute("SELECT username FROM users WHERE email = ?", email)[0]["username"]
    rank = db.execute("SELECT rank FROM users WHERE email = ?", email)[0]["rank"].to_i

    return {user_id: user_id, username: username, rank: rank}
end

def email_exist(email)
    if db.execute("SELECT email from users WHERE email = ?", email).exist?
        return True
    else
        return False
    end
end