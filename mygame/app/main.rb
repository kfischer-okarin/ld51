require 'smaug.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  render(args.outputs, args.state)
end

def setup(args)
  args.state.villagers = [Villager.build(x: 20, y: 20)]
  args.state.icons = animation_frames('sprites/icons.json')
  args.state.menu = [
    { rect: { x: 5, y: 5, w: 15, h: 15 }, icon: :house },
    { rect: { x: 25, y: 5, w: 15, h: 15 }, icon: :wheat }
  ]
end

def animation_frames(path)
  Animations::AsespriteJson.read(path).transform_values { |animation|
    {}.tap { |sprite|
      Animations.start!(sprite, animation: animation)
    }
  }
end

def render(gtk_outputs, state)
  gtk_outputs.background_color = PALETTE[:green].to_a
  screen = gtk_outputs[:screen]
  screen.width = 320
  screen.height = 180
  state.villagers.each do |villager|
    sprite = villager[:sprite]
    sprite[:x] = villager[:x] - 3
    sprite[:y] = villager[:y]
    AnimatedSprite.perform_tick(sprite, animation: :walk)
    screen.primitives << sprite
  end

  state.menu.each do |item|
    rect = item[:rect]
    screen.primitives << state.icons[:background].merge(PALETTE[:dark_brown]).merge(rect)
    screen.primitives << state.icons[item[:icon]].merge(rect)
    screen.primitives << state.icons[:border].merge(rect)
  end
  gtk_outputs.primitives << { x: 0, y: 0, w: 1280, h: 720, path: :screen }.sprite!
end

# Dawnbringer 32 color palette
PALETTE = {
  black: { r: 0x00, g: 0x00, b: 0x00 },
  dark_grey: { r: 0x22, g: 0x20, b: 0x34 },
  dark_brown: { r: 0x45, g: 0x28, b: 0x3c },
  bright_green: { r: 0x99, g: 0xe5, b: 0x50 },
  green: { r: 0x6a, g: 0xbe, b: 0x30 },
  blue_grey: { r: 0xcb, g: 0xdb, b: 0xfc }
}

PALETTE.each_value do |color|
  color.define_singleton_method(:to_a) { [r, g, b] }
  color.freeze
end

module Villager
  class << self
    def build(x:, y:)
      @animations ||= Animations::AsespriteJson.read('sprites/villager.json')
      {
        x: x,
        y: y,
        sprite: AnimatedSprite.build(animations: @animations)
      }
    end
  end
end

module Menu
end

$gtk.reset
