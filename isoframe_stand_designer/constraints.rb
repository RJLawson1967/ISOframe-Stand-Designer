# frozen_string_literal: true
# Keep floor-sitting ISOframe items on the floorspace top plane.
#
# v0.1.44: Wave Z-ONLY via origin. Never touch XY or rotation. Observers must
# not start nested operations during Move (that cancelled moves / XY snap-back).
#
# v0.1.78: freestanding floor accessories (Oval Counter + KEY_FLOOR_SLIDE) also
# Z-locked via world bounds min Z.
#
# v0.1.79: ALL floor-sitting items share one clamp — Wave starter/extension +
# freestanding accessories. Feet (world AABB min Z) → Floorspace.module_base_z.
# XY slide + Z rotation OK. Tables and media screens (wall-plane siblings) are
# excluded; host-follow / flex still call ensure_module_on_floor! for S+E.

module ISOframe
  module StandDesigner
    module Constraints
      # Absolute Z tolerance (SketchUp internal inches). ~0.01 mm.
      Z_TOL = 0.01.mm

      module_function

      def install!
        return if @installed
        @app_observer = AppObs.new
        Sketchup.add_observer(@app_observer)
        attach!(Sketchup.active_model) if Sketchup.active_model
        @installed = true
      end

      def attach!(model)
        return unless model
        @entity_observers ||= {}
        unless @entity_observers[model.object_id]
          obs = ModuleZObserver.new
          model.entities.add_observer(obs)
          @entity_observers[model.object_id] = obs
        end
        # Note: no ModelObserver onTransactionCommit — that re-ran snaps after
        # every edit and, with nested ops, fought the Move tool (XY snap-back).
        Floorspace.ensure_locked!(model)
        snap_all_floor_sitting!(model)
        Tables.install_erase_observer!(model) if defined?(Tables)
        Screens.install_erase_observer!(model) if defined?(Screens)
      rescue StandardError => e
        puts "[ISOframe] Constraints.attach! failed: #{e.message}"
      end

      def correcting?
        @correcting
      end

      def with_correcting
        return if @correcting
        @correcting = true
        begin
          yield
        ensure
          @correcting = false
        end
      end

      def isoframe_module?(entity)
        return false unless entity && entity.valid?
        return false unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        type = Attributes.get(entity, Constants::KEY_TYPE)
        type == Constants::TYPE_STARTER || type == Constants::TYPE_EXTENSION
      end

      # Freestanding floor accessory: Oval Counter (and future floor-placed
      # items tagged KEY_FLOOR_SLIDE). Never Wave / table / screen siblings.
      def freestanding_floor?(entity)
        return false unless entity && entity.valid?
        return false unless entity.is_a?(Sketchup::ComponentInstance)
        return false if isoframe_module?(entity)
        return false if defined?(Tables) && Tables.table_instance?(entity)
        return false if defined?(Screens) && Screens.screen_instance?(entity)
        slide = Attributes.get(entity, Constants::KEY_FLOOR_SLIDE, '').to_s
        return true if slide == '1' || slide.downcase == 'true'
        Attributes.get(entity, Constants::KEY_TYPE).to_s == Constants::TYPE_COUNTER
      end

      # Anything whose feet must stay on the floorspace top.
      def floor_sitting?(entity)
        return false unless entity && entity.valid?
        return false if defined?(Tables) && Tables.table_instance?(entity)
        return false if defined?(Screens) && Screens.screen_instance?(entity)
        isoframe_module?(entity) || freestanding_floor?(entity)
      end

      def mark_floor_slide!(entity)
        return unless entity && entity.valid?
        Attributes.set(entity, Constants::KEY_FLOOR_SLIDE, '1')
        entity
      end

      # Top-level modules: transformation.origin is world origin.
      # Nested (unique group host): climb one level when the host def has a
      # single instance — still only used to READ world Z.
      def world_origin_z(entity)
        return 0.0 unless entity && entity.valid?
        tr = entity.transformation
        parent = entity.parent
        parent = parent.parent if parent.is_a?(Sketchup::Entities)
        if parent.is_a?(Sketchup::ComponentDefinition)
          insts = parent.instances.to_a.select { |i| i && i.valid? }
          if insts.size == 1
            tr = insts.first.transformation * tr
          end
        end
        tr.origin.z
      rescue StandardError
        entity.transformation.origin.z
      end

      # World Z of the lowest point (feet). Falls back to origin Z.
      def world_feet_z(entity)
        return world_origin_z(entity) unless entity && entity.valid?
        bb = entity.bounds
        return world_origin_z(entity) if bb.nil? || bb.empty?
        bb.min.z
      rescue StandardError
        world_origin_z(entity)
      end

      # Pure Z translation. Preserves XY + rotation. Feet → floorspace top.
      def snap_floor_sitting_to_floor!(entity)
        return false unless floor_sitting?(entity)
        target = Floorspace.module_base_z(entity.model)
        z = world_feet_z(entity)
        dz = target - z
        return false if dz.abs <= Z_TOL
        entity.transform!(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, dz)))
        true
      rescue StandardError
        false
      end

      # Wave API (flex / place / height) — same feet clamp.
      def snap_z_to_floor!(entity)
        return false unless isoframe_module?(entity)
        snap_floor_sitting_to_floor!(entity)
      end

      # Freestanding API — same feet clamp.
      def snap_freestanding_to_floor!(entity)
        return false unless freestanding_floor?(entity)
        snap_floor_sitting_to_floor!(entity)
      end

      def snap_all_modules!(model)
        return unless model
        each_wave_module(model) { |ent| snap_z_to_floor!(ent) }
      end

      def snap_all_freestanding!(model)
        return unless model
        model.active_entities.grep(Sketchup::ComponentInstance).each do |ent|
          next unless freestanding_floor?(ent)
          snap_freestanding_to_floor!(ent)
        end
      end

      def snap_all_floor_sitting!(model)
        snap_all_modules!(model)
        snap_all_freestanding!(model)
      end

      def each_wave_module(model, &block)
        return unless model
        walk_entities(model.active_entities, &block)
      end

      def walk_entities(entities, &block)
        return unless entities
        entities.each do |e|
          next unless e && e.valid?
          if isoframe_module?(e)
            yield e
            next
          end
          if e.is_a?(Sketchup::Group)
            walk_entities(e.entities, &block)
          end
          # Do NOT walk into arbitrary component definitions — that found nested
          # non-scene geometry and caused spurious corrections.
        end
      end

      def ensure_module_on_floor!(entity)
        mark_floor_slide!(entity) if isoframe_module?(entity)
        snap_z_to_floor!(entity)
      end

      def ensure_freestanding_on_floor!(entity)
        mark_floor_slide!(entity)
        snap_freestanding_to_floor!(entity)
      end

      class AppObs < Sketchup::AppObserver
        def expectsStartupModelNotifications
          true
        end

        def onNewModel(model)
          Constraints.attach!(model)
        end

        def onOpenModel(model)
          Constraints.attach!(model)
        end
      end

      # Live Move: correct Z only, with NO nested start_operation (nested ops
      # abort the Move tool and restore the pre-move transform → XY snap-back).
      class ModuleZObserver < Sketchup::EntitiesObserver
        def onElementAdded(_entities, entity)
          correct_z_only(entity)
        end

        def onElementModified(_entities, entity)
          correct_z_only(entity)
        end

        private

        def correct_z_only(entity)
          return if Constraints.correcting?
          return unless entity && entity.valid?
          return unless Constraints.floor_sitting?(entity)

          target = Floorspace.module_base_z(entity.model)
          z = Constraints.world_feet_z(entity)
          return if (z - target).abs <= Constraints::Z_TOL

          Constraints.with_correcting do
            Constraints.snap_floor_sitting_to_floor!(entity)
          end
        rescue StandardError
          nil
        end
      end
    end
  end
end
