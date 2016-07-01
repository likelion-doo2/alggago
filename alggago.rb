# Encoding: UTF-8
require 'gosu'
require 'chipmunk'
require 'singleton'
require 'slave'
require "xmlrpc/client"
require 'childprocess'
require 'rbconfig'

WIDTH, HEIGHT = 1000, 700
TICK = 1.0/60.0
NUM_STONES = 7
PLAYER_COLOR = ["black", "white"]
STONE_DIAMETER = 50
RESTITUTION = 0.9
BOARD_FRICTION = 1.50
STONE_FRICTION = 0.5
ROTATIONAL_FRICTION = 0.04
FINGER_POWER = 3
UI_PIVOT = 100
MAX_POWER = 700.0

# Layering of sprites
module ZOrder
  Board, Stone, Mouse = 0, 1, 2
end

def is_port_open?(port)
  begin
    s = TCPServer.new("127.0.0.1", port)
  rescue Errno::EADDRINUSE
    return false
  end
  s.close
  return true
end

# Detection of OS
def is_windows?
  case RbConfig::CONFIG['host_os']
  when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    return true
  else
    return false
  end
end

class Alggago < Gosu::Window

  def init_game
    @winner = "white"
    @gameover = false
    @can_throw = true
    @selected_stone = nil
    @servers = Array.new

    @players.each do |player|
      player.stones.each do |stone|
        @space.remove_body(stone.body)
        @space.remove_shape(stone.shape)
      end
      player.stones.clear
    end
    @players.clear

    PLAYER_COLOR.each do |player_color|
      player = Player.new(player_color, NUM_STONES)
      player.stones.each do |stone|
        @space.add_body(stone.body)
        @space.add_shape(stone.shape)
      end
      @players << player
    end

    @player_turn = @players[0]

    #Load AI
    ais = Dir.entries(".").map {|x| x if /^ai_[[:alnum:]]+.rb$/.match(x)}.compact
    xml_port = 8000
    slaves = Array.new
    ais.each do |x|
      (xml_port..8080).to_a.each do |p|
        if is_port_open?(p)
          xml_port = p
          break
        end
      end
      if is_windows?
        slaves << ChildProcess.build("ruby", x, xml_port.to_s).start
      else
        slaves << Slave.object(:async => true){ `ruby #{x} #{xml_port}` }
      end
      @servers << XMLRPC::Client.new("localhost", "/", xml_port)
      xml_port += 1
    end

    0.upto(@servers.size - 1) do |count|
      server_connection = false
      while !server_connection
        begin
          @players[count].player_name = @servers[count].call("alggago.get_name")
          @players[count].ai_flag = true
          server_connection = true
        rescue Errno::ECONNREFUSED
        end
      end
    end
  end
  
  def initialize
    super(WIDTH, HEIGHT, false)
    self.caption = '알까고!'

    @players = Array.new
    @space = CP::Space.new
    @board  = Board.instance
    @font = Gosu::Font.new(self, Gosu::default_font_name, 18)

    init_game

  end

  def update
    @space.step(TICK)
    @can_throw = true
    @players.each do |player|
      player.update
      player.stones.each do |stone| 
        @can_throw = false if (stone.body.w != 0) or (stone.body.v.x != 0) or (stone.body.v.y != 0) 
        if stone.should_delete 
          @space.remove_body(stone.body)
          @space.remove_shape(stone.shape)
          player.number_of_stones -= 1
          player.stones.delete stone
        end
      end
    end

    @players.each do |player| 
      if player.number_of_stones <= 0 and !@gameover
        @gameover = true 
        @winner = if player.color == "white" then "black" else "white" end
      end
    end
  end

  def draw
    @board.draw
    @players.each { |player| player.draw }

    if @gameover
      @font.draw("게임끝!  #{@winner} 승리!!", 720, UI_PIVOT + 20, 1.0, 1.0, 1.0)
    else
      pivot_font_y_position = {"black" => UI_PIVOT + 150, "white" => UI_PIVOT + 220}
      moveable = if @can_throw then "가능" else "불가능" end

      @font.draw("이동 가능 여부 : #{moveable}", 720, UI_PIVOT + 20, 1.0, 1.0, 1.0)
      @font.draw("다음 턴 : #{@player_turn.color}", 720, UI_PIVOT + 40, 1.0, 1.0, 1.0)

      @players.each do |player|
        @font.draw("#{player.color} : #{player.player_name}", 720, 
                      pivot_font_y_position[player.color], 1.0, 1.0, 1.0)
        @font.draw("남은 돌 : #{player.number_of_stones}개", 720, 
                      pivot_font_y_position[player.color] + 20, 1.0, 1.0, 1.0)
      end
    end

    @font.draw("새로 시작하기 : R", 720, UI_PIVOT + 370, 1.0, 1.0, 1.0)
    @font.draw("턴 넘기기 : P", 720, UI_PIVOT + 390, 1.0, 1.0, 1.0)
    @font.draw("다음 턴 연산하기 : N", 720, UI_PIVOT + 410, 1.0, 1.0, 1.0)
    @font.draw("제작 : 멋쟁이사자처럼", 780, 670, 1.0, 1.0, 1.0)
  end

  def needs_cursor?
    true
  end

  def restart
    init_game
  end

  def pass_turn
    if @can_throw and !@gameover
      @player_turn = if @player_turn == @players[0]
                        @players[1]
                     elsif @player_turn == @players[1]
                        @players[0]
                     end
    end
  end

  def calculate
    if @player_turn.ai_flag and @can_throw and !@gameover
      my_index = if @player_turn == @players[0] then 0 else 1 end
      opposite_index = if @player_turn == @players[0] then 1 else 0 end
      my_position = @players[my_index].stones.map {|s| [s.body.p.x, s.body.p.y]}
      opposite_position = @players[opposite_index].stones.map {|s| [s.body.p.x, s.body.p.y]}

      number, x_strength, y_strength, message = 
          @servers[my_index].call(
                  "alggago.calculate", 
                  [my_position] + [opposite_position]
                )
      puts "\n[BEGIN] MESSAGE FROM AI"
      puts message
      puts "[END] MESSAGE FROM AI\n"

      reduced_x, reduced_y = reduce_speed(x_strength, y_strength)
      @player_turn.stones[number].body.v = CP::Vec2.new(reduced_x, reduced_y)
      pass_turn
    end
  end

  def reduce_speed x, y
    if x*x + y*y > MAX_POWER*MAX_POWER
      co = MAX_POWER / Math.sqrt(x*x + y*y) 
      return x*co, y*co
    else
      return x, y
    end
  end

  def button_down(id) 
    can_throw = true
    if can_throw
      case id 
      when Gosu::KbR 
        restart
      when Gosu::KbP 
        pass_turn
      when Gosu::KbN 
        calculate
      when Gosu::MsLeft
        if !@player_turn.ai_flag and !@gameover
          @player_turn.stones.each do |s|
            @selected_stone = s if (((s.body.p.x < mouse_x) and 
                                    (s.body.p.x + STONE_DIAMETER > mouse_x)) and 
                                    ((s.body.p.y < mouse_y) and 
                                     (s.body.p.y + STONE_DIAMETER > mouse_y)))
          end
        end
      end 
    end
  end

  def button_up(id)
    case id 
    when Gosu::MsLeft
      if !@selected_stone.nil?
        x_diff = mouse_x - (@selected_stone.body.p.x + STONE_DIAMETER/2.0)
        y_diff = mouse_y - (@selected_stone.body.p.y + STONE_DIAMETER/2.0)

        @selected_stone.body.v = CP::Vec2.new(x_diff * FINGER_POWER, y_diff * FINGER_POWER)
        pass_turn
      end
      @selected_stone = nil
    end 
  end
end

class Board
  include Singleton
  def initialize
    @image = Gosu::Image.new("media/board_logo.png")
  end

  def draw
    image_resize_ratio = HEIGHT / @image.height.to_f
    @image.draw(0, 0, ZOrder::Board, image_resize_ratio, image_resize_ratio)
  end 
end

class Player
  attr_reader :stones, :color
  attr_accessor :player_name, :ai_flag, :number_of_stones
  def initialize(color, num)
    @stones = Array.new
    @color = color
    @player_name = "사람_#{Array.new(6){rand(10)}.join}"
    @ai_flag = false
    @number_of_stones = NUM_STONES

    num.times { @stones << Stone.new(@color) }
  end
  
  def draw
    @stones.each {|stone| stone.draw}
  end

  def update
    @stones.each do |stone|
      stone.update
      if (stone.body.p.x + STONE_DIAMETER/2.0 > HEIGHT) or 
                              (stone.body.p.x + STONE_DIAMETER/2.0 < 0) or
                              (stone.body.p.y + STONE_DIAMETER/2.0 > HEIGHT) or 
                              (stone.body.p.y + STONE_DIAMETER/2.0 < 0)
        stone.should_delete = true
      end
    end
  end
end

class Stone
  attr_reader :body, :shape 
  attr_accessor :should_delete
  def initialize(color)
    @should_delete = false
    @body = CP::Body.new(1, CP::moment_for_circle(1.0, 0, 1, CP::Vec2.new(0, 0))) 
    
    position_y = rand((HEIGHT/2).to_i - 100) + 50
    position_y = position_y + HEIGHT/2.0 if color == "white"
    @body.p = CP::Vec2.new(rand(HEIGHT - 100) + 50, position_y) 
   #@body.v = CP::Vec2.new(rand(HEIGHT)-HEIGHT/2, rand(HEIGHT)-HEIGHT/2)

    @shape = CP::Shape::Circle.new(body, STONE_DIAMETER/2.0, CP::Vec2.new(0, 0))
    @shape.e = RESTITUTION
    @shape.u = STONE_FRICTION

    @stone_body = Gosu::Image.new("media/#{color}_stone.png")
    @logo_body = Gosu::Image.new("media/likelion_logo.png")
  end

  def update
    #update speed
    new_vel_x, new_vel_y = 0.0, 0.0
    if @body.v.x != 0 and @body.v.y != 0
      new_vel_x = get_reduced_velocity(@body.v.x, @body.v.length)
      new_vel_y = get_reduced_velocity(@body.v.y, @body.v.length)
    end
    @body.v = CP::Vec2.new(new_vel_x, new_vel_y)

    #update speed of angle
    new_rotational_v = 0
    new_rotational_v = get_reduced_rotational_velocity @body.w if @body.w != 0
    @body.w = new_rotational_v
  end

  def draw
    @stone_body.draw(@body.p.x, @body.p.y, ZOrder::Stone,
                          STONE_DIAMETER/@stone_body.width.to_f, STONE_DIAMETER/@stone_body.height.to_f)
    @logo_body.draw_rot(@body.p.x + STONE_DIAMETER/2.0, @body.p.y + STONE_DIAMETER/2.0, 
                          ZOrder::Stone, @body.a.radians_to_gosu, 0.5, 0.5, 
                          0.85 * (STONE_DIAMETER/@stone_body.width.to_f), 
                          0.85 * (STONE_DIAMETER/@stone_body.height.to_f), 
                          0x88ffffff)
  end 

  private
  def get_reduced_velocity original_velocity, original_velocity_length
    if original_velocity.abs <= BOARD_FRICTION * (original_velocity.abs / original_velocity_length)
      return 0 
    else 
      return (original_velocity.abs / original_velocity) * 
                (original_velocity.abs - BOARD_FRICTION * (original_velocity.abs / original_velocity_length))
    end
  end

  private
  def get_reduced_rotational_velocity velocity
    if velocity.abs <= ROTATIONAL_FRICTION
      return 0
    else
      return (velocity.abs / velocity) * (velocity.abs - ROTATIONAL_FRICTION)
    end
  end
end

@window = Alggago.new
@window.show
