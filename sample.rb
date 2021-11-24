class Fuga
  def display
    "fuga hello"
  end
end

class Hoge < Fuga
  def display
    "hoge hello"
  end

  def self.message
    p "message :" + display
  end
end

Hoge.message