# frozen_string_literal: true
# Fabric product sizes (v0.1.87). Isolated from Wave Constants::HEIGHTS_MM / bay.
# Width is outer-to-outer (edge-to-edge). Fabric covers entire Al frame; Z ≥ floor top.

module ISOframe
  module StandDesigner
    module Products
      module Fabric
        module Constants
          POST_MM = 37.0
          HALF_POST_MM = POST_MM / 2.0
          # Graphic fabric sheet thickness (mm) on the Al posts (front).
          GRAPHIC_THICKNESS_MM = 3.0
          GRAPHIC_FRONT_CLEARANCE_MM = 1.0
          # Fabric runs from floorspace top (local Z=0) so the whole Al frame is covered.
          GRAPHIC_Z_BOT_MM = 0.0
          # Fabric overhangs the post tip slightly (same idea as Wave).
          GRAPHIC_TOP_ABOVE_POST_MM = 5.0

          # Round Al bracing between posts (diameter mm). Length = bay outer − POST.
          BRACE_DIAMETER_MM = 12.5
          BRACE_SEGMENTS = 20
          # Brace centre-line Z (mm AFF / local) by height class.
          # Super-Maxi: four braces (keep Midi 1400 when stepping up) + 2200.
          BRACE_Z_MM = {
            'midi' => [950.0, 1400.0].freeze,
            'maxi' => [950.0, 1600.0].freeze,
            'super_maxi' => [950.0, 1400.0, 1600.0, 2200.0].freeze,
            'ultra_maxi' => [950.0, 1600.0, 3000.0].freeze
          }.freeze

          STARTER_WIDTH_MM = 900.0
          WIDTH_STEP_MM = 250.0
          # Compose remainder after starter (largest first).
          EXTENSION_WIDTHS_MM = [1000.0, 750.0, 500.0, 250.0].freeze

          HEIGHTS_MM = {
            'midi' => 2270.0,
            'maxi' => 2470.0,
            'super_maxi' => 3000.0,
            'ultra_maxi' => 3470.0
          }.freeze
          DEFAULT_HEIGHT = 'midi'
          HEIGHT_SNAP_ORDER = %w[midi maxi super_maxi ultra_maxi].freeze

          DEFN_PREFIX = 'ISOframe Fabric Wall v87'
          INSTANCE_NAME = 'ISOframe Fabric Wall'
          GROUP_POST = 'FabricPost'
          GROUP_GRAPHIC = 'FabricGraphic'
          GROUP_RAIL_TOP = 'FabricRailTop'
          GROUP_RAIL_BOT = 'FabricRailBot'
          GROUP_BRACE = 'FabricBrace'

          POST_RGB = [170, 176, 182].freeze
          GRAPHIC_RGB = [210, 220, 235].freeze
          BRACE_RGB = [160, 166, 172].freeze
        end
      end
    end
  end
end
