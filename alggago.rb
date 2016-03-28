# Encoding: UTF-8
require 'singleton'
require 'gosu'
require 'chipmunk'
require 'rmagick'

WIDTH, HEIGHT = 1000, 700
TICK = 1.0/60.0
NUM_STONES = 20
PLAYER_COLOR = ["black", "white"]
FRICTION_FACTOR = 1.50

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
    @body.v = CP::Vec2.new(rand(500)-250, rand(500)-250)

    @shape = CP::Shape::Circle.new(body, 23, CP::Vec2.new(0, 0))
    @shape.e = 0.9

    @image_body = Gosu::Image.new("media/#{@color}_stone_likelion.png", :tileable => true)
  end

  def update
    new_vel_x = 0.0
    new_vel_y = 0.0
    if @body.v.x != 0 and @body.v.y != 0
      new_vel_x = (@body.v.x.abs / @body.v.x) * (@body.v.x.abs - FRICTION_FACTOR * (@body.v.x.abs / @body.v.length))
      new_vel_y = (@body.v.y.abs / @body.v.y) * (@body.v.y.abs - FRICTION_FACTOR * (@body.v.y.abs / @body.v.length))
    end
    @body.v = CP::Vec2.new(new_vel_x, new_vel_y)
  end

  def draw
    @image_body.draw_rot(@body.p.x, @body.p.y, ZOrder::Stone, @body.a.radians_to_gosu, 0.5, 0.5, 0.23, 0.23)
  end 
end

window = Alggago.new
window.show
