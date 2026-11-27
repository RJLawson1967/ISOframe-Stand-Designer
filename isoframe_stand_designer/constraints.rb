# frozen_string_literal: true
# Keep floor-sitting ISOframe items on the floorspace top plane.
#
# v0.1.44: Wave Z-ONLY. Never touch XY or rotation. Observers must not start
# nested operations during Move (that cancelled moves / XY snap-back).
#
# v0.1.78–79: freestanding + Wave share floor-sitting clamp.
#
# v0.1.80: harden clamp — EntityObserver on each floor-sitting instance,
# ModelObserver onTransactionCommit/Undo/Redo, ToolsObserver on tool change,
# plus EntitiesObserver. Wave feet = world origin Z (place contract); freestanding
# feet = world AABB min Z. Re-clamp after flex via ensure_module_on_floor!.
# Tables / media screens still excluded.

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
        @model_observers ||= {}
        @tools_observers ||= {}
        @instance_observers ||= {}

        unless @entity_observers[model.object_id]
          obs = ModuleZObserver.new
          model.entities.add_observer(obs)
          @entity_observers[model.object_id] = obs
        end

        unless @model_observers[model.object_id]
          mobs = FloorModelObserver.new
          model.add_observer(mobs)
          @model_observers[model.object_id] = mobs
        end

        begin
          tools = model.tools
          if tools && !@tools_observers[model.object_id]
            tobs = FloorToolsObserver.new
            tools.add_observer(tobs)
            @tools_observers[model.object_id] = tobs
          end
        rescue StandardError => e
          puts "[ISOframe] ToolsObserver attach failed: #{e.message}"
        end

        Floorspace.ensure_locked!(model)
        watch_all_floor_sitting!(model)
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
        watch_entity!(entity)
        entity
      end

      def watch_entity!(entity)
        return unless entity && entity.valid? && floor_sitting?(entity)
        @instance_observers ||= {}
        eid = entity.entityID
        return if @instance_observers[eid]
        obs = FloorEntityObserver.new
        entity.add_observer(obs)
        @instance_observers[eid] = obs
      rescue StandardError => e
        puts "[ISOframe] watch_entity! failed: #{e.message}"
      end

      def watch_all_floor_sitting!(model)
        return unless model
        each_wave_module(model) { |ent| watch_entity!(ent) }
        model.active_entities.grep(Sketchup::ComponentInstance).each do |ent|
          next unless freestanding_floor?(ent)
          watch_entity!(ent)
        end
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

      # Wave: origin Z is the foot sole (place contract).
      # Freestanding: world AABB min Z (feet of baked mesh).
      def world_feet_z(entity)
        return 0.0 unless entity && entity.valid?
        if isoframe_module?(entity)
          return world_origin_z(entity)
        end
        bb = entity.bounds
        return world_origin_z(entity) if bb.nil? || bb.empty?
        bb.min.z
      rescue StandardError
        world_origin_z(entity)
      end

      # Pure Z translation. Preserves XY + rotation. Feet → floorspace top.
      def snap_floor_sitting_to_floor!(entity)
        return false unless floor_sitting?(entity)
        watch_entity!(entity)
        target = Floorspace.module_base_z(entity.model)
        z = world_feet_z(entity)
        dz = target - z
        return false if dz.abs <= Z_TOL
        entity.transform!(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, dz)))
        true
      rescue StandardError
        false
      end

      def correct_entity_z!(entity)
        return false if correcting?
        return false unless entity && entity.valid?
        return false unless floor_sitting?(entity)
        target = Floorspace.module_base_z(entity.model)
        z = world_feet_z(entity)
        return false if (z - target).abs <= Z_TOL
        with_correcting { snap_floor_sitting_to_floor!(entity) }
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
        return unless model
        return if correcting?
        with_correcting do
          snap_all_modules!(model)
          snap_all_freestanding!(model)
        end
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

      # Live Move: correct Z only, with NO nested start_operation.
      class ModuleZObserver < Sketchup::EntitiesObserver
        def onElementAdded(_entities, entity)
          Constraints.watch_entity!(entity) if Constraints.floor_sitting?(entity)
          Constraints.correct_entity_z!(entity)
        end

        def onElementModified(_entities, entity)
          Constraints.correct_entity_z!(entity)
        end
      end

      # Fires when a watched instance's transform changes (native Move included).
      class FloorEntityObserver < Sketchup::EntityObserver
        def onChangeEntity(entity)
          Constraints.correct_entity_z!(entity)
        rescue StandardError
          nil
        end
      end

      # After any operation (Move commit, Flex, etc.) re-clamp all floor-sitters.
      class FloorModelObserver < Sketchup::ModelObserver
        def onTransactionCommit(model)
          Constraints.snap_all_floor_sitting!(model)
        rescue StandardError
          nil
        end

        def onTransactionUndo(model)
          Constraints.snap_all_floor_sitting!(model)
        rescue StandardError
          nil
        end

        def onTransactionRedo(model)
          Constraints.snap_all_floor_sitting!(model)
        rescue StandardError
          nil
        end
      end

      # When leaving Move (or any tool change), snap feet again.
      class FloorToolsObserver < Sketchup::ToolsObserver
        def onActiveToolChanged(tools, _tool_name)
          model = (tools.respond_to?(:model) ? tools.model : nil) || Sketchup.active_model
          Constraints.snap_all_floor_sitting!(model)
        rescue StandardError
          nil
        end
      end
    end
  end
end
