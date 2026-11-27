# frozen_string_literal: true
require 'sketchup.rb'

module ISOframe
  module StandDesigner
    EXTENSION_DIR = File.dirname(__FILE__).freeze unless defined?(EXTENSION_DIR)

    def self.load_files!
      relative = %w[
        constants
        attributes
        selection_util
        wall_math
        wall_graph
        license
        floorspace
        mesh_import
        geometry
        lights
        tables
        artwork
        constraints
        tools/place_starter
        tools/place_extension
        tools/flex_tool
        tools/height_swap
        tools/add_light
        tools/add_table
        ui/dialog
        ui/menu
      ]
      relative.each do |rel|
        begin
          Sketchup.require "isoframe_stand_designer/#{rel}"
        rescue LoadError
          load File.join(EXTENSION_DIR, "#{rel}.rb")
        rescue StandardError => e
          # Do not abort the whole extension if one file fails — panel/menu
          # would otherwise never wire (looks like "all buttons dead").
          puts "[ISOframe] failed loading #{rel}: #{e.class}: #{e.message}"
        end
      end
    end

    unless file_loaded?(__FILE__)
      load_files!
      AppMenu.install!
      Constraints.install!
      file_loaded(__FILE__)
      puts "[ISOframe Stand Designer] v#{EXTENSION_VERSION} loaded"
    end
  end
end
