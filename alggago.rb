# Encoding: UTF-8
require 'gosu'
require 'chipmunk'
require 'singleton'

WIDTH, HEIGHT = 1000, 700
TICK = 1.0/60.0
NUM_STONES = 20
PLAYER_COLOR = ["black", "white"]
STONE_DIAMETER = 50
RESTITUTION = 0.9
BOARD_FRICTION = 1.50
STONE_FRICTION = 0.5

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
end

class Board
  include Singleton
  attr_reader :body, :shape
  def initialize
    @image = Gosu::Image.new("media/board_logo.png", :tileable => true)
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
    @num_stones = num
    @color = color

    @num_stones.times { @stones << Stone.new(@color) }
  end
  
  def draw
    @stones.each {|stone| stone.draw}
  end

  def update
    @stones.each {|stone| stone.update}
  end
end

class Stone
  attr_reader :body, :shape 
  def initialize(color)
    @color = color

    @body = CP::Body.new(1, CP::moment_for_circle(1.0, 0, 1, CP::Vec2.new(0, 0))) 
    @body.p = CP::Vec2.new(rand(HEIGHT), rand(HEIGHT)) 
    @body.v = CP::Vec2.new(rand(HEIGHT)-HEIGHT/2, rand(HEIGHT)-HEIGHT/2)

    @shape = CP::Shape::Circle.new(body, STONE_DIAMETER/2.0, CP::Vec2.new(0, 0))
    @shape.e = RESTITUTION
    @shape.u = STONE_FRICTION

    @image_body = Gosu::Image.new("media/#{@color}_stone_likelion.png", :tileable => true)
  end

  def update
    new_vel_x, new_vel_y = 0.0, 0.0
    if @body.v.x != 0 and @body.v.y != 0
      new_vel_x = get_reduced_velocity(@body.v.x, @body.v.length)
      new_vel_y = get_reduced_velocity(@body.v.y, @body.v.length)
    end
    @body.v = CP::Vec2.new(new_vel_x, new_vel_y)
  end

  def draw
    @image_body.draw_rot(@body.p.x, @body.p.y, ZOrder::Stone, 
                          @body.a.radians_to_gosu, 0.5, 0.5, STONE_DIAMETER/@image_body.width.to_f, STONE_DIAMETER/@image_body.height.to_f)
  end 

  private
  def get_reduced_velocity original_velocity, original_velocity_length
    (original_velocity.abs / original_velocity) * 
      (original_velocity.abs - BOARD_FRICTION * (original_velocity.abs / original_velocity_length))
  end
end

window = Alggago.new
window.show
