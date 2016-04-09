# Encoding: UTF-8
require 'gosu'
require 'chipmunk'
require 'singleton'

WIDTH, HEIGHT = 1000, 700
TICK = 1.0/60.0
NUM_STONES = 10
PLAYER_COLOR = ["black", "white"]
STONE_DIAMETER = 50
RESTITUTION = 0.9
BOARD_FRICTION = 1.50
STONE_FRICTION = 0.5
ROTATIONAL_FRICTION = 0.04
FINGER_POWER = 3

# Layering of sprites
module ZOrder
  Board, Stone, Mouse = 0, 1, 2
end

class Alggago < Gosu::Window
  
  def initialize
    super(WIDTH, HEIGHT, false)
    self.caption = '알까고!'

    @space = CP::Space.new
    @board  = Board.instance
    @players = Array.new

    PLAYER_COLOR.each do |player_color|
      player = Player.new(player_color, NUM_STONES)
      player.stones.each do |stone|
        @space.add_body(stone.body)
        @space.add_shape(stone.shape)
      end
      @players << player
    end
    @player_turn = @players[0]
    @selected_stone = nil
  end

  def update
    @space.step(TICK)
    @players.each { |player| player.update }
  end

  def draw
    @board.draw
    @players.each { |player| player.draw }
  end

  def needs_cursor?
    true
  end

  def button_down(id) 
    can_throw = true
    @players.each do |p|
      p.stones.each { |s| can_throw = false if (s.body.w != 0) or (s.body.v.x != 0) or (s.body.v.y != 0) }
    end
    if can_throw
      case id 
      when Gosu::MsLeft
        @player_turn.stones.each do |s|
          @selected_stone = s if (((s.body.p.x < mouse_x) and (s.body.p.x + STONE_DIAMETER > mouse_x)) and 
                                    ((s.body.p.y < mouse_y) and (s.body.p.y + STONE_DIAMETER > mouse_y)))
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
        @player_turn = if @player_turn == @players[0]
                          @players[1]
                       elsif @player_turn == @players[1]
                          @players[0]
                       end
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
  attr_reader :stones
  def initialize(color, num)
    @stones = Array.new
    @color = color

    num.times { @stones << Stone.new(@color) }
  end
  
  def draw
    @stones.each {|stone| stone.draw}
  end

  def update
    @stones.each do |stone|
      stone.update
      @stones.delete stone if (stone.body.p.x + STONE_DIAMETER/2.0 > HEIGHT) or 
                              (stone.body.p.x + STONE_DIAMETER/2.0 < 0) or
                              (stone.body.p.y + STONE_DIAMETER/2.0 > HEIGHT) or 
                              (stone.body.p.y + STONE_DIAMETER/2.0 < 0)
    end
  end
end

class Stone
  attr_reader :body, :shape 
  def initialize(color)
    @body = CP::Body.new(1, CP::moment_for_circle(1.0, 0, 1, CP::Vec2.new(0, 0))) 
    @body.p = CP::Vec2.new(rand(HEIGHT), rand(HEIGHT)) 
    @body.v = CP::Vec2.new(rand(HEIGHT)-HEIGHT/2, rand(HEIGHT)-HEIGHT/2)

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

  def get_reduced_rotational_velocity velocity
    if velocity.abs <= ROTATIONAL_FRICTION
      return 0
    else
      return (velocity.abs / velocity) * (velocity.abs - ROTATIONAL_FRICTION)
    end
  end
end

window = Alggago.new
window.show
