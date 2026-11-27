# frozen_string_literal: true
# Floorspace slab on the ground plane (Z=0 .. FLOOR_THICKNESS_MM). Must be
# defined before placing modules. Wave feet sit on the floor TOP when a
# floorspace exists (see module_base_z); without a floor, feet stay on Z=0.
# After create/update the floorspace group is locked so SketchUp Move/Rotate/Scale
# cannot change it. Modify Floorspace unlocks → rebuilds → re-locks.

module ISOframe
  module StandDesigner
    module Floorspace
      # Solid floor thickness (mm). Face at Z=0, extruded upward.
      FLOOR_THICKNESS_MM = 10.0

      module_function

      def defined?(model = Sketchup.active_model)
        w = Attributes.get(model, Constants::KEY_FLOOR_W)
        d = Attributes.get(model, Constants::KEY_FLOOR_D)
        w && d && w.to_f > 0 && d.to_f > 0
      end

      # World Z of the module origin / foot sole. On top of the floor when a
      # floorspace is defined; otherwise the ground plane (Z=0).
      def module_base_z(model = Sketchup.active_model)
        # Call Floorspace.defined? — not Ruby's defined? keyword.
        Floorspace.defined?(model) ? FLOOR_THICKNESS_MM.mm : 0.0
      end

      def require_defined!
        return true if defined?
        UI.messagebox('Define floorspace first (Extensions → ISOframe Stand Designer → Floorspace…).')
        false
      end

      def floorspace_group?(entity)
        return false unless entity && entity.valid?
        return false unless entity.is_a?(Sketchup::Group)
        Attributes.get(entity, Constants::KEY_TYPE) == Constants::TYPE_FLOORSPACE
      end

      def find_group(model = Sketchup.active_model)
        gid = Attributes.get(model, Constants::KEY_FLOOR_GID)
        return nil unless gid
        model.active_entities.grep(Sketchup::Group).find do |g|
          g.valid? && g.entityID == gid.to_i
        end
      end

      def lock!(group)
        return unless group && group.valid?
        group.locked = true if group.respond_to?(:locked=)
      rescue StandardError
        nil
      end

      def unlock!(group)
        return unless group && group.valid?
        group.locked = false if group.respond_to?(:locked=)
      rescue StandardError
        nil
      end

      # On load / after upgrade: lock any existing ISOframe floorspace group.
      def ensure_locked!(model = Sketchup.active_model)
        group = find_group(model)
        return unless group
        unless floorspace_group?(group)
          Attributes.set(group, Constants::KEY_TYPE, Constants::TYPE_FLOORSPACE)
          Attributes.set(group, Constants::KEY_RANGE, Constants::RANGE_WAVE)
        end
        lock!(group)
      end

      def prompt_and_draw!
        model = Sketchup.active_model
        cur_w = Attributes.get(model, Constants::KEY_FLOOR_W, 5000)
        cur_d = Attributes.get(model, Constants::KEY_FLOOR_D, 4000)
        input = UI.inputbox(
          ['Width (mm)', 'Depth (mm)'],
          [cur_w.to_f.to_i, cur_d.to_f.to_i],
          'ISOframe Floorspace'
        )
        return false unless input
        w_mm, d_mm = input.map(&:to_f)
        if w_mm <= 0 || d_mm <= 0
          UI.messagebox('Width and depth must be positive.')
          return false
        end
        draw!(model, w_mm, d_mm)
      end

      def draw!(model, width_mm, depth_mm)
        model.start_operation('ISOframe Floorspace', true)
        begin
          clear_existing!(model)
          remove_scale_figures!(model)
          w = width_mm.to_f.mm
          d = depth_mm.to_f.mm
          group = model.active_entities.add_group
          group.name = 'ISOframe Floorspace'
          face = group.entities.add_face(
            Geom::Point3d.new(0, 0, 0),
            Geom::Point3d.new(w, 0, 0),
            Geom::Point3d.new(w, d, 0),
            Geom::Point3d.new(0, d, 0)
          )
          if face
            # Extrude upward so the slab spans Z=0 .. FLOOR_THICKNESS_MM.
            face.reverse! if face.normal.z < 0
            face.pushpull(FLOOR_THICKNESS_MM.mm)
            mat = Sketchup::Color.new(220, 220, 210)
            group.entities.grep(Sketchup::Face).each do |f|
              f.material = mat
              f.back_material = mat
            end
          end
          Attributes.set(group, Constants::KEY_TYPE, Constants::TYPE_FLOORSPACE)
          Attributes.set(group, Constants::KEY_RANGE, Constants::RANGE_WAVE)
          Attributes.set(model, Constants::KEY_FLOOR_W, width_mm.to_f)
          Attributes.set(model, Constants::KEY_FLOOR_D, depth_mm.to_f)
          Attributes.set(model, Constants::KEY_FLOOR_GID, group.entityID)
          lock!(group)
          # Raise any already-placed modules so feet sit on the new floor top.
          Constraints.snap_all_modules!(model)
          model.commit_operation
          Sketchup.status_text =
            "Floorspace #{width_mm.to_i} × #{depth_mm.to_i} × #{FLOOR_THICKNESS_MM.to_i} mm (locked)"
          true
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Floorspace failed: #{e.message}")
          false
        end
      end

      def clear_existing!(model)
        gid = Attributes.get(model, Constants::KEY_FLOOR_GID)
        return unless gid
        model.active_entities.grep(Sketchup::Group).each do |g|
          next unless g.valid? && g.entityID == gid.to_i
          unlock!(g)
          g.erase!
        end
      rescue StandardError
        nil
      end

      # Remove SketchUp default scale figure (Sree / woman / named scale people).
      def remove_scale_figures!(model = Sketchup.active_model)
        patterns = [
          /\Asree\z/i,
          /\Asusan\z/i,
          /\Asang\z/i,
          /\Achris\z/i,
          /scale\s*figure/i,
          /sketchup.*figure/i,
          /\Awoman\z/i,
          /\Aman\z/i
        ]
        model.active_entities.to_a.each do |ent|
          next unless ent.valid?
          next unless ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
          name = if ent.respond_to?(:definition)
                   ent.definition.name.to_s
                 else
                   ent.name.to_s
                 end
          ent.erase! if patterns.any? { |re| name =~ re }
        end
      rescue StandardError
        nil
      end
    end
  end
end
