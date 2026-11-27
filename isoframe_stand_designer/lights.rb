# frozen_string_literal: true
# LED flood lights on Wave module posts from bundled LED_Flood_Light.skp.
# State on the instance (KEY_LIGHT_LEFT / KEY_LIGHT_RIGHT) so rebuilds re-embed.
#
# v0.1.48: bake arm → graphic +Y (measure + explode). Mesh untouched.
# v0.1.50: +20.1° CCW from above (undo over-rotation) — LOCKED plan yaw.
# v0.1.51: both L/R shift 70.7 mm viewer-left (graphic-front) + 10 mm down.

module ISOframe
  module StandDesigner
    module Lights
      module_function

      GROUP_LIGHT_LEFT = 'FloodLightLeft'
      GROUP_LIGHT_RIGHT = 'FloodLightRight'
      # Fresh name so dealers drop any cached v45–v48 orientation.
      DEFN_FLOOD = 'ISOframe LED Flood Light v50'
      SKP_FLOOD = 'LED_Flood_Light.skp'
      # Square stub seats this far into the post-top hole (mm).
      INSERT_MM = 50.0
      # Module graphic face / arm target in definition space.
      GRAPHIC_FRONT = Geom::Vector3d.new(0, 1, 0)
      # v0.1.50 LOCKED: 20.1° anti-clockwise from above (RH Z-up = +angle).
      PLAN_CCW_UNDO_DEG = 20.1
      # v0.1.51: looking at graphic front, viewer-left = local +X (ψ=180° Place).
      SHIFT_LEFT_MM = 70.7
      SHIFT_DOWN_MM = 10.0

      def light_on?(inst, side)
        key = side_key(side)
        return false unless key
        Attributes.get(inst, key, '0').to_s == '1'
      end

      def set_light!(inst, side, on)
        key = side_key(side)
        return false unless key && inst && inst.valid?
        Attributes.set(inst, key, on ? '1' : '0')
        sync!(inst)
        on
      end

      def toggle!(inst, side)
        set_light!(inst, side, !light_on?(inst, side))
      end

      def sync!(inst)
        return unless inst && inst.valid?
        return unless Attributes.module_attrs?(inst)

        type = Attributes.get(inst, Constants::KEY_TYPE)
        height_key = Attributes.get(inst, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT)
        flex = Attributes.get(inst, Constants::KEY_FLEX, 0.0).to_f
        graphic_mm = Constants::HEIGHTS_MM[height_key.to_s] ||
                     Constants::HEIGHTS_MM[Constants::DEFAULT_HEIGHT]
        tip_mm = Geometry.post_tip_height_mm(graphic_mm)

        Geometry.force_unique_definition!(inst, type, height_key)
        defn = inst.definition
        clear_light_groups!(defn)

        left_on = light_on?(inst, :left)
        right_on = light_on?(inst, :right)
        return unless left_on || right_on

        flood_defn = flood_definition!(inst.model)
        # UI Left/Right = graphic-front viewer sides (not raw local hinge/free).
        # RH Place ψ=180°: local free → viewer LEFT; local hinge → viewer RIGHT.
        if left_on
          embed_light!(
            defn, flood_defn,
            center: Geometry.end_post_center_local(flex),
            yaw_deg: flex,
            tip_mm: tip_mm,
            name: GROUP_LIGHT_LEFT
          )
        end
        if right_on
          embed_light!(
            defn, flood_defn,
            center: Geometry.hinge_center_local,
            yaw_deg: 0.0,
            tip_mm: tip_mm,
            name: GROUP_LIGHT_RIGHT
          )
        end
        inst
      rescue StandardError => e
        puts "[ISOframe] Lights.sync! failed: #{e.message}"
        nil
      end

      # Load LED_Flood_Light.skp; bake arm → +Y into DEFN_FLOOD. Mesh untouched.
      def flood_definition!(model)
        existing = model.definitions[DEFN_FLOOD]
        return existing if existing && !existing.image? && existing.entities.size > 0

        path = MeshImport.model_path(SKP_FLOOD)
        unless File.file?(path)
          return legacy_obj_definition!(model)
        end

        begin
          loaded = model.definitions.load(path)
        rescue StandardError => e
          puts "[ISOframe] LED SKP load failed: #{e.message}"
          return legacy_obj_definition!(model)
        end

        defn = model.definitions[DEFN_FLOOD] || model.definitions.add(DEFN_FLOOD)
        defn.entities.clear! if defn.entities.size > 0

        arm_yaw = yaw_aligning_arm_to_graphic(loaded) +
                  (PLAN_CCW_UNDO_DEG * Math::PI / 180.0)
        puts "[ISOframe] LED arm bake (→+Y then +#{PLAN_CCW_UNDO_DEG}° CCW): " \
             "#{(arm_yaw * 180.0 / Math::PI).round(1)}°"
        rot = Geom::Transformation.rotation(
          Geom::Point3d.new(0, 0, 0),
          Geom::Vector3d.new(0, 0, 1),
          arm_yaw
        )
        # Instance + explode bakes the plan yaw into the definition contents so
        # place cannot drop it (v0.1.46–47 fixed −90° never showed for Richard).
        inst = defn.entities.add_instance(loaded, rot)
        inst.explode if inst.respond_to?(:explode)
        soften_definition_edges!(defn)
        defn
      end

      # Plan angle (radians about Z) that takes the SKP's XY arm toward +Y.
      # Stub is at the origin; arm runs toward the bounds centroid in XY.
      def yaw_aligning_arm_to_graphic(loaded_defn)
        arm = arm_direction_xy(loaded_defn)
        return -Math::PI / 2.0 if arm.nil? || arm.length < 1.0e-6

        front = GRAPHIC_FRONT
        # atan2(sin, cos) of the signed angle from arm → +Y about Z.
        cross = arm.x * front.y - arm.y * front.x
        dot = arm.x * front.x + arm.y * front.y
        Math.atan2(cross, dot)
      end

      def arm_direction_xy(loaded_defn)
        bb = loaded_defn.bounds
        return nil unless bb

        # Prefer bounds centroid (stub at origin → arm toward mass of fixture).
        cx = bb.center.x
        cy = bb.center.y
        # If centroid is near origin, fall back to the larger horizontal extent.
        if Math.hypot(cx, cy) < 1.0e-3
          dx = bb.max.x - bb.min.x
          dy = bb.max.y - bb.min.y
          if dx >= dy
            # Extent mostly along X — pick the side farther from 0.
            cx = (bb.max.x.abs >= bb.min.x.abs) ? bb.max.x : bb.min.x
            cy = 0.0
          else
            cy = (bb.max.y.abs >= bb.min.y.abs) ? bb.max.y : bb.min.y
            cx = 0.0
          end
        end
        vec = Geom::Vector3d.new(cx, cy, 0)
        return nil if vec.length < 1.0e-6
        vec.normalize!
        vec
      rescue StandardError => e
        puts "[ISOframe] arm_direction_xy failed: #{e.message}"
        nil
      end

      def legacy_obj_definition!(model)
        # OBJ arm is already authored along +Y (graphic front) — no plan bake.
        MeshImport.definition_from_obj!(
          model,
          'ISOframe Flood Light v38',
          'flood_light.obj',
          color: Sketchup::Color.new(48, 52, 58)
        )
      end

      # Post tip XY + viewer-left / down shifts; Z = tip − INSERT − SHIFT_DOWN.
      # Plan yaw LOCKED in flood_defn (arm→+Y + PLAN_CCW_UNDO). yaw_deg = post only.
      def embed_light!(parent_defn, flood_defn, center:, yaw_deg:, tip_mm:, name:)
        z = (tip_mm.to_f - INSERT_MM - SHIFT_DOWN_MM).mm
        z_axis = Geom::Vector3d.new(0, 0, 1)
        origin = Geom::Point3d.new(0, 0, 0)
        yaw = Geom::Transformation.rotation(
          origin, z_axis, yaw_deg.to_f * Math::PI / 180.0
        )
        # 70.7 mm toward graphic-front viewer left (= local +X under RH ψ=180°).
        move = Geom::Transformation.translation(
          Geom::Vector3d.new(
            center.x + SHIFT_LEFT_MM.mm,
            center.y,
            z
          )
        )
        group = parent_defn.entities.add_group
        group.name = name
        group.entities.add_instance(flood_defn, yaw)
        group.transform!(move)
        group
      end

      # Soft/smooth/hide edges for a clean look — does not move vertices.
      def soften_definition_edges!(defn, seen = nil)
        seen ||= {}
        return unless defn
        return if seen[defn.object_id]
        seen[defn.object_id] = true

        defn.entities.to_a.each do |e|
          next unless e && e.valid?
          if e.is_a?(Sketchup::Edge)
            e.soft = true
            e.smooth = true
            e.hidden = true
          elsif e.is_a?(Sketchup::ComponentInstance)
            soften_definition_edges!(e.definition, seen)
          elsif e.is_a?(Sketchup::Group)
            soften_entities_edges!(e.entities, seen)
          end
        end
      rescue StandardError => e
        puts "[ISOframe] soften light edges failed: #{e.message}"
      end

      def soften_entities_edges!(ents, seen)
        return unless ents
        ents.to_a.each do |e|
          next unless e && e.valid?
          if e.is_a?(Sketchup::Edge)
            e.soft = true
            e.smooth = true
            e.hidden = true
          elsif e.is_a?(Sketchup::ComponentInstance)
            soften_definition_edges!(e.definition, seen)
          elsif e.is_a?(Sketchup::Group)
            soften_entities_edges!(e.entities, seen)
          end
        end
      end

      def clear_light_groups!(defn)
        return unless defn
        defn.entities.to_a.each do |e|
          next unless e.respond_to?(:name)
          name = e.name.to_s
          next unless name == GROUP_LIGHT_LEFT || name == GROUP_LIGHT_RIGHT
          e.erase! if e.valid?
        end
      end

      def side_key(side)
        case side.to_s.downcase
        # left/right = graphic-front; free/hinge alias those posts under ψ=180°.
        when 'left', 'l', 'free' then Constants::KEY_LIGHT_LEFT
        when 'right', 'r', 'hinge' then Constants::KEY_LIGHT_RIGHT
        else nil
        end
      end
    end
  end
end
