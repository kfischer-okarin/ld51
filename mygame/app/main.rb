require 'smaug.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  process_inputs(args.inputs, args.state)
  render(args.outputs, args.state)
end

def setup(args)
  state = args.state
  state.villagers = [Villager.build(x: 20, y: 20)]
  state.money = 100
  state.icons = animation_frames('sprites/icons.json')
  state.menu.items = [
    { rect: { x: 5, y: 164, w: 15, h: 15 }, icon: :house },
    { rect: { x: 25, y: 164, w: 15, h: 15 }, icon: :wheat }
  ]
  state.menu.hovered_item = nil
end

def animation_frames(path)
  Animations::AsespriteJson.read(path).transform_values { |animation|
    {}.tap { |sprite|
      Animations.start!(sprite, animation: animation)
    }
  }
end

def process_inputs(inputs, state)
  mouse = {
    x: inputs.mouse.x.idiv(4),
    y: inputs.mouse.y.idiv(4),
    w: 0,
    h: 0
  }
  handle_menu(mouse, state.menu)
end

def handle_menu(mouse, menu)
  menu.hovered_item = menu.items.find { |item| mouse.inside_rect?(item[:rect]) }
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

  render_ui(screen, state)

  gtk_outputs.primitives << { x: 0, y: 0, w: 1280, h: 720, path: :screen }.sprite!
end

def render_ui(gtk_outputs, state)
  gtk_outputs.primitives << {
    x: 0, y: 163, w: 320, h: 17,
    path: :pixel
  }.sprite!(PALETTE[:dark_grey])

  menu = state.menu
  menu.items.each do |item|
    rect = item[:rect]
    gtk_outputs.primitives << state.icons[:background].merge(PALETTE[:dark_brown]).merge(rect)
    gtk_outputs.primitives << state.icons[item[:icon]].merge(rect)
    gtk_outputs.primitives << state.icons[:border].merge(rect) if menu.hovered_item == item
  end

  gtk_outputs.primitives << state.icons[:coin].merge(x: 278, y: 164)
  gtk_outputs.primitives << {
    x: 317, y: 172, text: state.money.to_s, font: 'fonts/kenney_pixel.ttf',
    size_enum: -5, alignment_enum: 2, vertical_alignment_enum: 1
  }.label!(PALETTE[:yellow])
end

# Dawnbringer 32 color palette
PALETTE = {
  black: { r: 0x00, g: 0x00, b: 0x00 },
  dark_grey: { r: 0x22, g: 0x20, b: 0x34 },
  dark_brown: { r: 0x45, g: 0x28, b: 0x3c },
  brown: { r: 0x66, g: 0x39, b: 0x31 },
  yellow: { r: 0xfb, g: 0xf2, b: 0x36 },
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
