require 'smaug.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  process_inputs(args.inputs, args.state)
  render(args.outputs, args.state)
end

def setup(args)
  state = args.state
  state.buildings = []
  state.villagers = [Villager.build(x: 20, y: 20)]
  state.money = 100
  state.menu.items = [
    {
      x: 5, y: 164, w: 15, h: 15, icon: :house,
      building: { type: :house, cost: 30 }
    },
    { x: 25, y: 164, w: 15, h: 15, icon: :wheat }
  ]
  state.mode = { type: :none }
end

def process_inputs(inputs, state)
  original_mouse = inputs.mouse
  state.mouse = {
    x: original_mouse.x.idiv(4),
    y: original_mouse.y.idiv(4),
    w: 0,
    h: 0,
    click: original_mouse.click,
    button_left: original_mouse.button_left
  }
  handle_menu(state)
  handle_building(state) if state.mode[:type] == :build
end

def handle_menu(state)
  mouse = state.mouse
  menu_items = state.menu.items
  clicked_item = nil
  menu_items.each do |item|
    Button.handle_mouse_input(mouse, item)
    clicked_item = item if item[:clicked]
  end
  return unless clicked_item

  state.mode = { type: :build, building: clicked_item[:building] }
  menu_items.each do |item|
    item[:selected] = item == clicked_item
  end
end

def handle_building(state)
  building = state.mode[:building]
  return unless building # TODO: Remove

  building_sprite = Sprites.buildings[building[:type]]
  building_preview = building_sprite.merge(
    x: state.mouse[:x] - building_sprite[:w].idiv(2),
    y: state.mouse[:y] - building_sprite[:h].idiv(2)
  )
  game_area = { x: 0, y: 0, w: 320, h: 163 }
  buildable = building_preview.inside_rect?(game_area) &&
              state.buildings.none? { |b| b.intersect_rect?(building_preview) } &&
              state.money >= building[:cost]
  state.building_preview = building_preview.merge(a: 200)
  state.building_preview.merge!(r: 255, g: 0, b: 0) unless buildable
  return unless state.mouse[:click] && buildable

  state.buildings << building_preview
  state.money -= building[:cost]
end

def render(gtk_outputs, state)
  gtk_outputs.background_color = PALETTE[:green].to_a
  screen = gtk_outputs[:screen]
  screen.width = 320
  screen.height = 180

  state.buildings.each do |building|
    screen.primitives << building
  end

  state.villagers.each do |villager|
    sprite = villager[:sprite]
    sprite[:x] = villager[:x] - 3
    sprite[:y] = villager[:y]
    AnimatedSprite.perform_tick(sprite, animation: :walk)
    screen.primitives << sprite
  end

  screen.primitives << state.building_preview if state.mode[:type] == :build

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
    rect = item.slice(:x, :y, :w, :h)
    bg_color = item[:selected] ? PALETTE[:orange] : PALETTE[:dark_brown]
    gtk_outputs.primitives << Sprites.icons[:background].merge(bg_color).merge(rect)
    gtk_outputs.primitives << Sprites.icons[item[:icon]].merge(rect)
    gtk_outputs.primitives << Sprites.icons[:border].merge(rect) if item[:hovered] && !item[:selected]
  end

  gtk_outputs.primitives << Sprites.icons[:coin].merge(x: 278, y: 164)
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
  orange: { r: 0xdf, g: 0x71, b: 0x26 },
  yellow: { r: 0xfb, g: 0xf2, b: 0x36 },
  bright_green: { r: 0x99, g: 0xe5, b: 0x50 },
  green: { r: 0x6a, g: 0xbe, b: 0x30 },
  dark_green: { r: 0x4b, g: 0x69, b: 0x2f },
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

module Sprites
  class << self
    def icons
      @icons ||= animation_frames('sprites/icons.json')
    end

    def buildings
      @buildings ||= animation_frames('sprites/buildings.json')
    end
  end
end

# TODO: Move to base framework
module Button
  class << self
    def handle_mouse_input(mouse, button)
      button[:hovered_ticks] ||= 0
      button[:pressed_ticks] ||= 0
      button[:ticks_since_released] ||= 0
      button[:hovered] = mouse.inside_rect?(button)
      button[:hovered_ticks] = button[:hovered] ? button[:hovered_ticks] + 1 : 0
      button[:clicked] = button[:hovered] && mouse.click
      button[:pressed] = button[:hovered] && mouse.button_left
      button[:released] = button[:pressed_ticks].positive? && !mouse.button_left
      button[:ticks_since_released] = button[:released] ? 0 : button[:ticks_since_released] + 1
      button[:pressed_ticks] = button[:pressed] ? button[:pressed_ticks] + 1 : 0
    end
  end
end

# TODO: Find a good way to integrate this into the framework
# Maybe instead of Animations::AsespriteJson - FileFormats::AsespriteJson.read_animations and read_sprites

def animation_frames(path)
  Animations::AsespriteJson.read(path).transform_values { |animation|
    {}.tap { |sprite|
      Animations.start!(sprite, animation: animation)
    }
  }
end

$gtk.reset
