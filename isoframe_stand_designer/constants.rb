# frozen_string_literal: true
module ISOframe
  module StandDesigner
    module Constants
      DICT = 'ISOframe_StandDesigner'
      RANGE_WAVE = 'wave'
      RANGE_FABRIC = 'fabric'
      TYPE_STARTER = 'starter'
      TYPE_EXTENSION = 'extension'
      TYPE_FLOORSPACE = 'floorspace'
      TYPE_COUNTER = 'counter'
      TYPE_FABRIC_WALL = 'fabric_wall'
      TYPE_FABRIC_JOIN = 'fabric_join'
      KEY_FABRIC_WIDTH_MM = 'fabric_width_mm'
      POST_MM = 37.0
      HALF_POST_MM = POST_MM / 2.0
      GRAPHIC_BAY_MM = 800.0
      BAY_CENTER_MM = GRAPHIC_BAY_MM
      # Overall graphic panel heights (mm) — Richard measures these in SketchUp.
      # Post tip is GRAPHIC_Z_BOT + HEIGHT − GRAPHIC_TOP_ABOVE_POST (see Geometry).
      HEIGHTS_MM = {
        'mini' => 2070.0,
        'midi' => 2270.0,
        'maxi' => 2470.0
      }.freeze
      DEFAULT_HEIGHT = 'midi'
      FLEX_MIN_DEG = -180
      FLEX_MAX_DEG = 180
      FLEX_STEP_DEG = 1
      FLEX_SNAP_DEG = [
        -180, -90, -75, -60, -45, -30, -15,
        0,
        15, 30, 45, 60, 75, 90, 180
      ].freeze
      FLEX_SNAP_TOLERANCE_DEG = 3.0
      POST_SECTION_MM = POST_MM
      # Flexi-link section: depth (into plan, behind graphic) × height (Z).
      # v0.1.41: depth 25 mm (was 37). Bottom Z set in Geometry.
      BEAM_DEPTH_MM = 25.0
      BEAM_THICKNESS_MM = 50.0
      KEY_FLOOR_W = 'floorspace_width_mm'
      KEY_FLOOR_D = 'floorspace_depth_mm'
      KEY_FLOOR_GID = 'floorspace_group_id'
      KEY_RANGE = 'range'
      KEY_TYPE = 'type'
      KEY_HEIGHT = 'height'
      KEY_FLEX = 'flex_angle'
      KEY_WALL = 'wall_id'
      # Wall-chain graph (minimal; written on Place, used by Flex hinge propagation).
      KEY_MODULE_ID = 'module_id'
      KEY_PREV_ID = 'prev_module_id'
      KEY_NEXT_ID = 'next_module_id'
      KEY_POST_HINGE = 'post_hinge_id'
      KEY_POST_FREE = 'post_free_id'
      KEY_CHAIN_INDEX = 'chain_index'
      # Artwork wallpaper (shared material across a wall's graphic fronts).
      KEY_ARTWORK_PATH = 'artwork_image_path'
      # Optional flood lights on module posts (persisted across flex rebuilds).
      KEY_LIGHT_LEFT = 'light_left'
      KEY_LIGHT_RIGHT = 'light_right'
      # Optional table add-on on a straight module ('keyboard', …). Empty = none.
      KEY_TABLE_TYPE = 'table_type'
      # Sibling table instance → host Wave module_id (v0.1.44+).
      KEY_TABLE_HOST = 'table_host_module_id'
      KEY_TABLE_KIND = 'table_kind'
      # Under-table graphic artwork (separate from wall wallpaper).
      KEY_TABLE_ARTWORK_PATH = 'table_artwork_image_path'
      # Freestanding counter (Oval first) — not attached to Wave S/E.
      KEY_COUNTER_KIND = 'counter_kind'
      KEY_COUNTER_ARTWORK_PATH = 'counter_artwork_image_path'
      # Floor-slide lock (v0.1.78+ freestanding; v0.1.79+ also Wave S/E):
      # translate in XY (and rotate about Z) but feet stay on floorspace top.
      KEY_FLOOR_SLIDE = 'floor_slide'
      # Media screen Small/Large on straight S/E (flexilink stays).
      KEY_SCREEN_TYPE = 'screen_type'
      KEY_SCREEN_KIND = 'screen_kind'
      KEY_SCREEN_HOST = 'screen_host_module_id'
      # Local-left post is always the definition hinge; Fix Right reparameterizes
      # the instance transform so the local-right post is fixed in world.
      HINGE_LEFT = 'left'
      HINGE_RIGHT = 'right'
      POST_JOIN_TOL_MM = 8.0
      PREFS_SECTION = 'ISOframeStandDesigner'
      PREFS_LICENSE_KEY = 'license_key'
      PREFS_LICENSE_OK = 'license_active'
    end
  end
end
