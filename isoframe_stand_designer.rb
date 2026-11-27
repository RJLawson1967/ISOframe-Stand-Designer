# frozen_string_literal: true
# ISOframe Stand Designer — SketchUp extension registration
# Load this file (or the packaged .rbz) from SketchUp's Plugins folder.
# SketchUp 2025+ · Mac + Windows

require 'sketchup.rb'
require 'extensions.rb'

module ISOframe
  module StandDesigner
    EXTENSION_NAME = 'ISOframe Stand Designer'
    EXTENSION_VERSION = '0.1.82'

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new(
        EXTENSION_NAME,
        'isoframe_stand_designer/main'
      )
      ex.description = 'Design ISOframe exhibition stands from Wave flexible modules.'
      ex.version     = EXTENSION_VERSION
      ex.copyright   = 'ISOframe'
      ex.creator     = 'ISOframe / Richard Lawson'
      Sketchup.register_extension(ex, true)
      file_loaded(__FILE__)
    end
  end
end
