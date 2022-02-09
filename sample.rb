class Fuga
  def display
    "fuga display"
  end

  def self.display
    "fuga class display"
  end
end

class Hoge < Fuga
  def display
    "hoge display"
  end

  def self.display
    super
    "hoge class display"
  end

  def self.message
    p "message : " + display
  end
end

Hoge.message

a = 5
b = 10

result = a < b ? a : b
p result

if a < b
  result = a
else
  result = b
end
p result


if (0..9) === (a + b)
  p "0~9"
elsif (10..19) === (a + b)
  p "10~19"
else
  p "20~"
end

case (a + b)
when (0..9)
  p "0~9"
when (10..19)
  p "10~19"
else
  p "20~"
end
