require 'smaug.rb'

require 'lib/extra_keys.rb'
require 'lib/debug_mode.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  process_inputs(args.inputs, args.state)
  render(args.outputs, args.state)
  update(args.state)
end

def setup(args)
  state = args.state
  state.buildings = []
  state.villagers = []
  state.money = 100
  state.menu.items = [
    {
      x: 5, y: 164, w: 15, h: 15, icon: :house,
      building: { type: :house, cost: 30, collider: { x: 4, y: 0, w: 16, h: 9 } }
    },
    {
      x: 25, y: 164, w: 15, h: 15, icon: :wheat,
      building: { type: :field, cost: 10 }
    }
  ]
  state.mode = { type: :none }

  $debug.log_color = { r: 255, g: 255, b: 255 }

  prepare_wheat_sprites(args)
end

def prepare_wheat_sprites(args)
  10.times do |i|
    oar_positions = generate_oar_positions
    (0..5).each do |stage|
      target = args.outputs[:"wheat_stage#{stage}_#{i}"]
      target.width = 24
      target.height = 26
      target.sprites << Sprites.buildings[:field].merge(x: 0, y: 0)
      next if stage.zero?

      oar_positions.each do |position|
        target.sprites << Sprites.wheat[:"stage#{stage}"].merge(position)
      end
    end
  end
end

def generate_oar_positions
  possible_positions = {}
  (2..21).each do |x|
    (1..21).each do |y|
      possible_positions[{ x: x, y: y }] = true
    end
  end

  [].tap { |result|
    while possible_positions.any?
      next_position = next_oar_position(possible_positions)
      position = next_position[:position]
      next_position[:invalidated_positions].each do |invalidated|
        possible_positions.delete invalidated
      end

      position[:x] -= 1
      result << position.merge(w: 3, h: 5, flip_horizontally: rand(2) == 1)
    end
  }
end

def next_oar_position(possible_positions)
  candidates = []

  2.times do
    position = possible_positions.keys.sample

    invalidated_positions = []

    (-1..1).each do |x|
      invalidated_positions << { x: position[:x] + x, y: position[:y] + 5 }
    end

    (-2..2).each do |x|
      invalidated_positions << { x: position[:x] + x, y: position[:y] + 4 }
      invalidated_positions << { x: position[:x] + x, y: position[:y] + 3 }
    end

    (-3..3).each do |x|
      invalidated_positions << { x: position[:x] + x, y: position[:y] + 2 }
      invalidated_positions << { x: position[:x] + x, y: position[:y] + 1 }
      invalidated_positions << { x: position[:x] + x, y: position[:y] + 0 }
      invalidated_positions << { x: position[:x] + x, y: position[:y] - 1 }
      invalidated_positions << { x: position[:x] + x, y: position[:y] - 2 }
    end

    (-2..2).each do |x|
      invalidated_positions << { x: position[:x] + x, y: position[:y] - 3 }
      invalidated_positions << { x: position[:x] + x, y: position[:y] - 4 }
    end

    (-1..1).each do |x|
      invalidated_positions << { x: position[:x] + x, y: position[:y] - 5 }
    end

    invalidated_positions.select! { |pos| possible_positions.key? pos }
    invalidated_positions.uniq!

    candidates << { position: position, invalidated_positions: invalidated_positions }
  end

  candidates.min_by { |c| c[:invalidated_positions].length }
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

  send(:"build_#{building[:type]}", state, building_preview.merge(building))
  state.money -= building[:cost]
end

def build_house(state, house)
  state.buildings << house
  state.villagers << Villager.build(x: house[:x] + 12, y: house[:y] - 8)
end

def build_field(state, field)
  rand_sprite_index = rand(10)
  state.buildings << {
    x: field[:x],
    y: field[:y],
    w: field[:w],
    h: 26,
    rand_sprite_index: rand(10),
    stage: 0,
    stage_ticks: 0,
    path: :"wheat_stage0_#{rand_sprite_index}"
  }.sprite!
end

def render(gtk_outputs, state)
  gtk_outputs.background_color = PALETTE[:green].to_a
  screen = gtk_outputs[:screen]
  screen.width = 320
  screen.height = 180

  state.buildings.each do |building|
    screen.primitives << building
    next unless debug_mode? && building[:collider]

    screen.primitives << building[:collider].to_border(
      x: building[:x] + building[:collider][:x],
      y: building[:y] + building[:collider][:y],
      r: 255, g: 0, b: 0
    )
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

def update(state)
  if state.tick_count.mod_zero?(5)
    state.villagers.each do |villager|
      villager[:movement] = { x: rand(3) - 1, y: rand(3) - 1 }
      villager[:x] += villager[:movement][:x]
      villager[:y] += villager[:movement][:y]
    end
  end
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
        movement: { x: 0, y: 0 },
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
      unless @buildings
        @buildings = animation_frames('sprites/buildings.json')
        @buildings[:field][:h] = 24
        @buildings[:field][:tile_h] = 24
      end

      @buildings
    end

    def wheat
      @wheat ||= animation_frames('sprites/wheat.json')
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
