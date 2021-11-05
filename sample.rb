class Hoge
  def full_name
    puts "sawa shuya"
  end

  private
  def age
    puts "24"
  end

  protected
  def hight
    puts "186"
  end
end

class Fuga < Hoge
  def name
    puts "shuya"
  end

  def name_and_address
    name
    address
  end

  def name_and_address
    hight
    age
  end

  private
  def address
    puts "saitama"
  end
end

fuga = Fuga.new
puts fuga.name, fuga.name_and_address, fuga.full_name