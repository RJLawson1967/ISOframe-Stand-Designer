# frozen_string_literal: true
# Keep Wave modules on the floor plane: world origin Z = Floorspace.module_base_z
# (floor top when floorspace exists, else Z=0).
#
# v0.1.44: Z-ONLY. Never touch XY or rotation. Observers must not start nested
# operations during Move (that cancelled moves and snapped modules back in XY).

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
        snap_all_modules!(model)
        Tables.install_erase_observer!(model) if defined?(Tables)
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

      # Pure Z translation in the entity's parent space. Preserves XY + rotation.
      def snap_z_to_floor!(entity)
        return false unless isoframe_module?(entity)
        target = Floorspace.module_base_z(entity.model)
        z = world_origin_z(entity)
        dz = target - z
        return false if dz.abs <= Z_TOL
        entity.transform!(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, dz)))
        true
      rescue StandardError
        false
      end

      def snap_all_modules!(model)
        return unless model
        each_wave_module(model) { |ent| snap_z_to_floor!(ent) }
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
        snap_z_to_floor!(entity)
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
          return unless Constraints.isoframe_module?(entity)

          target = Floorspace.module_base_z(entity.model)
          z = Constraints.world_origin_z(entity)
          return if (z - target).abs <= Constraints::Z_TOL

          Constraints.with_correcting do
            Constraints.snap_z_to_floor!(entity)
          end
        rescue StandardError
          nil
        end
      end
    end
  end
end
