def tick(args)
  render(args.outputs, args.state)
end

def render(gtk_outputs, state)
  gtk_outputs.background_color = PALETTE[:green].to_a
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
