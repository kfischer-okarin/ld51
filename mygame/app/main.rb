require 'smaug.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  render(args.outputs, args.state)
end

def setup(args)
  args.state.villagers = [Villager.build(x: 20, y: 20)]
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
  gtk_outputs.primitives << { x: 0, y: 0, w: 1280, h: 720, path: :screen }.sprite!
end

# Dawnbringer 32 color palette
PALETTE = {
  bright_green: { r: 0x99, g: 0xe5, b: 0x50 },
  green: { r: 0x6a, g: 0xbe, b: 0x30 }
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

$gtk.reset
