module DebugExtension
  class Debug
    attr_accessor :log_color

    def initialize(args)
      @args = args
      @active = !$gtk.production
      @debug_mode = false
      @debug_logs = []
      @static_debug_logs = {}
      @last_debug_y = 720
      @log_color = { r: 0, g: 0, b: 0 }
      @flags = {}
    end

    def register_flag(id, key:, name:, values: nil)
      values ||= [false, true]
      @flags[id] = { key: key, values: values, current_value_index: 0, name: name }
    end

    def flag(id)
      flag = @flags[id]
      flag[:values][flag[:current_value_index]]
    end

    def time_block_last_execute(name)
      start = Time.now.to_f
      yield
      duration_ms = ((Time.now.to_f - start) * 1000).floor
      static_log(:"time_#{name}", "Last execution of #{name}: #{duration_ms}ms")
    end

    def debug_mode?
      @debug_mode
    end

    def static_log(name, message)
      @static_debug_logs[name] = message
    end

    def remove_static_log(name)
      @static_debug_logs.delete(name)
    end

    def log(message, pos = nil, show_always: false)
      return unless @active && (show_always || @debug_mode)

      label_pos = pos || [0, @last_debug_y]
      @last_debug_y -= 20 unless pos
      @debug_logs << @log_color.merge(x: label_pos.x, y: label_pos.y, text: message).label!
    end

    def tick
      return unless @active

      log($gtk.current_framerate.to_i.to_s, show_always: true)
      log('DEBUG MODE') if @debug_mode

      handle_debug_function
      handle_debug_flags

      @static_debug_logs.each_value do |message|
        log(message)
      end

      add_background if @debug_mode
      @args.outputs.debug << @debug_logs
      @debug_logs.clear
      @last_debug_y = 720
    end

    private

    DEBUG_FUNCTIONS = {
      f9: :toggle_debug,
      f10: :reset_with_same_seed,
      f11: :reset,
      f12: :take_screenshot
    }.freeze

    def handle_debug_function
      pressed_key = DEBUG_FUNCTIONS.keys.find { |key| @args.inputs.keyboard.key_down.send(key) }
      send(DEBUG_FUNCTIONS[pressed_key]) if pressed_key
    end

    def handle_debug_flags
      @flags.each do |id, f|
        if @args.inputs.keyboard.key_down.send(f[:key])
          f[:current_value_index] = (f[:current_value_index] + 1) % f[:values].length
        end

        log("#{f[:name]}: #{flag(id)} (#{f[:key]})")
      end
    end

    def add_background
      max_w = @debug_logs.map { |log| $gtk.calcstringbox(log[:text], 1, 'font.ttf')[0] }.max
      @args.outputs.debug << { x: 0, y: @last_debug_y, w: max_w, h: 720 - @last_debug_y, r: 255, g: 255, b: 255, a: 200}.solid!
      @debug_logs.each do |log|
        log.merge!(r: 0, g: 0, b: 0)
      end
    end

    def toggle_debug
      @debug_mode = !@debug_mode
    end

    def reset_with_same_seed
      $gtk.reset
    end

    def reset
      $gtk.reset seed: (Time.now.to_f * 1000).to_i
    end

    def take_screenshot
      time = Time.now
      formatted_time = format(
        '%d-%02d-%02dT%02d-%02d-%02d',
        time.year, time.month, time.day, time.hour, time.min, time.sec
      )
      @args.outputs.screenshots << {
        x: 0, y: 0, w: 1280, h: 720, a: 255,
        path: "screenshot-#{formatted_time}.png"
      }
    end
  end

  # Adds args.debug
  module Args
    def debug
      @debug ||= Debug.new(self)
      $debug = @debug
    end
  end

  # Runs the debug tick
  module Runtime
    def tick_core
      @args.debug.tick
      super
    end
  end
end

GTK::Args.include DebugExtension::Args unless GTK::Args.is_a? DebugExtension::Args
GTK::Runtime.prepend DebugExtension::Runtime unless GTK::Runtime.is_a? DebugExtension::Runtime

def debug_mode?
  $debug&.debug_mode?
end
