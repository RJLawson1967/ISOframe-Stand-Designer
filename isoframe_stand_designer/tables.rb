# frozen_string_literal: true
# Table add-ons attach onto an existing straight Wave module (starter or
# extension). They do NOT replace the module.
#
# v0.1.52: authoritative assembly Keyboard_with_Extension.skp — bake the real
# keyboard table with the attach transform discovered vs the Wave module in that
# file. Sibling instance so Delete leaves the graphic module; Flex-link removed
# while attached (37 mm beams come from SKP). Under-table graphic takes separate
# artwork from the backwall.
# v0.1.53: fix name match — SKP def is "Keyboard Attachment wrap" / instance
# "keyboard attachment" / "Keyboard table attachment…"; old regex required
# keyboard+attachment with nothing between and missed the real def.
# v0.1.54: orientation-only — after discover attach, rotate 90° CW looking from
# the right (−90° about +X), then 180° looking from above (180° about +Z),
# both about the attach origin (position offsets deferred).
# v0.1.55: counter was under the floor / upside down after v0.1.54 — keep those
# two rotations, then flip 180° looking from either side (+180° about +X).
# Also: Apply Table Artwork — match SKP GraphicHint / Rolable / Graphic Keyboard
# Attachment names (depth-0 after explode), ensure TableGraphicHint exists.

module ISOframe
  module StandDesigner
    module Tables
      module_function

      REGISTRY = {
        'keyboard' => {
          label: 'Keyboard Table',
          straight_only: true,
          skp_file: 'Keyboard_with_Extension.skp',
          # Fresh name so dealers drop any cached v43–v54 bake/pose.
          defn_name: 'ISOframe Table Keyboard SKP v55',
          instance_name: 'ISOframe Keyboard Table',
          graphic_group: 'TableGraphicHint'
        }
      }.freeze

      SKP_KEYBOARD = 'Keyboard_with_Extension.skp'
      # Definition names in Keyboard_with_Extension.skp (Richard):
      #   "Keyboard Attachment wrap" (± DC suffix after ^)
      #   "Keyboard table attachment_Graphic Keyboard Attachment (Rolable)"
      # Instance name in the assembly: "keyboard attachment"
      # Do NOT require "keyboard" immediately before "attachment" — "table" sits between.
      KB_DEF_RE = /keyboard.*attach|attach.*keyboard/i
      KB_INSTANCE_RE = /keyboard\s*(table\s*)?attachment/i
      KB_WRAP_RE = /keyboard\s*attachment\s*wrap/i
      # Loose parts to gather if no single keyboard component (v0.1.43-style fallback).
      KEEP_PART_RE = /
        keyboard|
        attachment\s*wrap|
        table\s*attachment|
        table\s*post|
        \b763\b|
        beam\s*straight|
        t-?box|
        keyboard\s*(base|lip|top)|
        adjustable\s*foot
      /ix
      SKIP_PART_RE = /
        \bsree\b|
        floorspace|
        isoframe\s*wave|
        flexibeam|
        \bprice\b|
        led\s*flood|
        flood\s*light
      /ix
      # Under-table graphic names in Keyboard_with_Extension.skp:
      #   nested groups "GraphicHint"; DC wrap suffix
      #   "…Graphic Keyboard Attachment (Rolable)"; stable tag TableGraphicHint.
      TABLE_GRAPHIC_RE = /
        table\s*graphic\s*hint|
        graphic\s*hint|
        graphic\s*keyboard|
        table\s*graphic|
        keyboard\s*attachment\s*wrap|
        rolable
      /ix
      TABLE_GRAPHIC_FIND_RE = /
        TableGraphicHint|
        GraphicHint|
        Graphic\s*Keyboard|
        Rolable
      /ix
      # Bay-center fallback when SKP pair discovery fails (mm → inches via .mm).
      FALLBACK_BAY_CENTER_MM = Constants::GRAPHIC_BAY_MM / 2.0

      def registry
        REGISTRY
      end

      def type_keys
        REGISTRY.keys
      end

      def label_for(type_key)
        entry = REGISTRY[type_key.to_s]
        entry ? entry[:label] : type_key.to_s
      end

      def table_on?(inst)
        !table_type(inst).empty?
      end

      def table_type(inst)
        Attributes.get(inst, Constants::KEY_TABLE_TYPE, '').to_s
      end

      def straight?(inst)
        Attributes.get(inst, Constants::KEY_FLEX, 0.0).to_f.abs < 0.5
      end

      def table_instance?(ent)
        return false unless ent && ent.valid? && ent.is_a?(Sketchup::ComponentInstance)
        kind = Attributes.get(ent, Constants::KEY_TABLE_KIND, '').to_s
        !kind.empty?
      end

      def toggle_selected!(type_key = 'keyboard')
        model = Sketchup.active_model
        insts = SelectionUtil.wave_modules_in_selection(model)
        # If user selected a table instance, resolve its host module.
        if insts.empty?
          model.selection.each do |e|
            next unless table_instance?(e)
            host = host_for_table(e)
            insts << host if host
          end
          insts.uniq!
        end
        if insts.empty?
          UI.messagebox(
            'Select a straight Wave starter or extension, then Keyboard Table.'
          )
          return false
        end

        model.start_operation("ISOframe Table #{label_for(type_key)}", true)
        begin
          attached = 0
          removed = 0
          skipped = 0
          insts.each do |inst|
            result = toggle_one!(inst, type_key)
            case result
            when :attached then attached += 1
            when :removed then removed += 1
            else skipped += 1
            end
          end
          model.commit_operation
          insts.each { |i| Constraints.ensure_module_on_floor!(i) if i && i.valid? }

          if attached + removed == 0 && skipped > 0
            UI.messagebox('Tables only attach to straight modules (flex = 0°). Straighten first.')
            return false
          end

          bits = []
          bits << "+#{attached}" if attached > 0
          bits << "−#{removed}" if removed > 0
          bits << "skipped #{skipped} bent" if skipped > 0
          Sketchup.status_text = "Table #{label_for(type_key)}: #{bits.join(' / ')}"
          true
        rescue StandardError => e
          model.abort_operation
          UI.messagebox("Table failed: #{e.message}")
          false
        end
      end

      def toggle_one!(inst, type_key)
        type_key = type_key.to_s
        return false unless REGISTRY.key?(type_key)
        return false unless SelectionUtil.wave_module?(inst)

        current = table_type(inst)
        if current == type_key
          remove!(inst)
          return :removed
        end
        return :bent unless straight?(inst)

        attach!(inst, type_key)
        :attached
      end

      def attach!(inst, type_key)
        type_key = type_key.to_s
        entry = REGISTRY[type_key]
        raise ArgumentError, "Unknown table type: #{type_key}" unless entry
        raise 'Tables only attach to straight modules' unless straight?(inst)

        # Drop any prior sibling table for this host.
        erase_table_instances_for_host!(inst)

        Attributes.set(inst, Constants::KEY_TABLE_TYPE, type_key)
        Attributes.set(inst, Constants::KEY_FLEX, 0.0)

        # Ensure host is unique + straight, Flex-link removed.
        type = Attributes.get(inst, Constants::KEY_TYPE)
        height_key = Attributes.get(inst, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT)
        Geometry.force_unique_definition!(inst, type, height_key)
        Geometry.rebuild_definition!(inst.definition, type, height_key, 0.0)
        Geometry.erase_flexi_beam!(inst.definition)
        Lights.sync!(inst) if defined?(Lights)
        Artwork.reapply_after_rebuild!(inst) if defined?(Artwork)

        place_table_instance!(inst, entry)
        Constraints.ensure_module_on_floor!(inst)
        inst
      end

      # Detach via menu/panel: erase sibling table only; rebuild host (Flex back).
      # Wave module instance stays in the model.
      def remove!(inst)
        return unless inst && inst.valid?
        erase_table_instances_for_host!(inst)
        Attributes.set(inst, Constants::KEY_TABLE_TYPE, '')
        type = Attributes.get(inst, Constants::KEY_TYPE)
        height_key = Attributes.get(inst, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT)
        Geometry.force_unique_definition!(inst, type, height_key)
        Geometry.rebuild_definition!(inst.definition, type, height_key, 0.0)
        Lights.sync!(inst) if defined?(Lights)
        Artwork.reapply_after_rebuild!(inst) if defined?(Artwork)
        Constraints.ensure_module_on_floor!(inst)
        inst
      end

      # Called after host flex/height rebuilds if KEY_TABLE_TYPE still set.
      def sync!(inst)
        return unless inst && inst.valid?
        return unless SelectionUtil.wave_module?(inst)

        type_key = table_type(inst)
        if type_key.empty?
          erase_table_instances_for_host!(inst)
          return
        end
        entry = REGISTRY[type_key]
        unless entry && straight?(inst)
          Attributes.set(inst, Constants::KEY_TABLE_TYPE, '')
          erase_table_instances_for_host!(inst)
          return
        end

        Geometry.erase_flexi_beam!(inst.definition)
        if find_table_instance_for_host(inst)
          reposition_table_for_host!(inst)
        else
          place_table_instance!(inst, entry)
        end
        Constraints.ensure_module_on_floor!(inst)
        Artwork.reapply_table_after_rebuild!(inst) if defined?(Artwork)
        inst
      rescue StandardError => e
        puts "[ISOframe] Tables.sync! failed: #{e.message}"
        nil
      end

      def place_table_instance!(host, entry)
        model = host.model
        mid = Attributes.get(host, Constants::KEY_MODULE_ID).to_s
        if mid.empty?
          mid = "mod_#{host.entityID}_#{Time.now.to_i}"
          Attributes.set(host, Constants::KEY_MODULE_ID, mid)
        end

        table_defn = keyboard_definition!(model, entry)
        local = attach_local_transform(model, entry)
        world_tr = host.transformation * local

        inst = model.active_entities.add_instance(table_defn, world_tr)
        inst.name = entry[:instance_name]
        Attributes.set(inst, Constants::KEY_TABLE_KIND, 'keyboard')
        Attributes.set(inst, Constants::KEY_TABLE_HOST, mid.to_s)
        # Carry any prior table artwork path from host → new sibling.
        prior = Attributes.get(host, Constants::KEY_TABLE_ARTWORK_PATH, '').to_s
        Attributes.set(inst, Constants::KEY_TABLE_ARTWORK_PATH, prior) unless prior.empty?
        Artwork.reapply_table_instance!(inst) if defined?(Artwork) && !prior.empty?
        inst
      end

      def reposition_table_for_host!(host)
        table = find_table_instance_for_host(host)
        return unless table && table.valid?
        entry = REGISTRY[table_type(host)] || REGISTRY['keyboard']
        local = attach_local_transform(host.model, entry)
        table.transformation = host.transformation * local
        table
      end

      def find_table_instance_for_host(host)
        mid = Attributes.get(host, Constants::KEY_MODULE_ID).to_s
        return nil if mid.empty?
        host.model.active_entities.grep(Sketchup::ComponentInstance).find do |e|
          next false unless table_instance?(e)
          Attributes.get(e, Constants::KEY_TABLE_HOST).to_s == mid
        end
      end

      def erase_table_instances_for_host!(host)
        mid = Attributes.get(host, Constants::KEY_MODULE_ID).to_s
        # Preserve table artwork path on the host before erase.
        existing = find_table_instance_for_host(host)
        if existing && existing.valid?
          path = Attributes.get(existing, Constants::KEY_TABLE_ARTWORK_PATH, '').to_s
          Attributes.set(host, Constants::KEY_TABLE_ARTWORK_PATH, path) unless path.empty?
        end
        host.model.active_entities.grep(Sketchup::ComponentInstance).each do |e|
          next unless table_instance?(e)
          next unless mid.empty? || Attributes.get(e, Constants::KEY_TABLE_HOST).to_s == mid
          e.erase! if e.valid?
        end
      rescue StandardError
        nil
      end

      def host_for_table(table_inst)
        mid = Attributes.get(table_inst, Constants::KEY_TABLE_HOST).to_s
        return nil if mid.empty?
        model = table_inst.model
        model.active_entities.grep(Sketchup::ComponentInstance).find do |e|
          next false unless SelectionUtil.wave_module?(e)
          Attributes.get(e, Constants::KEY_MODULE_ID).to_s == mid
        end
      end

      # Called when a table instance was erased (Delete key) — restore host only.
      def handle_table_erased!(model, host_module_id)
        return if host_module_id.to_s.empty?
        host = model.active_entities.grep(Sketchup::ComponentInstance).find do |e|
          next false unless SelectionUtil.wave_module?(e)
          Attributes.get(e, Constants::KEY_MODULE_ID).to_s == host_module_id.to_s
        end
        return unless host && host.valid?
        return if table_type(host).empty?

        Attributes.set(host, Constants::KEY_TABLE_TYPE, '')
        type = Attributes.get(host, Constants::KEY_TYPE)
        height_key = Attributes.get(host, Constants::KEY_HEIGHT, Constants::DEFAULT_HEIGHT)
        flex = Attributes.get(host, Constants::KEY_FLEX, 0.0).to_f
        Geometry.force_unique_definition!(host, type, height_key)
        Geometry.rebuild_definition!(host.definition, type, height_key, flex.abs < 0.5 ? 0.0 : flex)
        Lights.sync!(host) if defined?(Lights)
        Artwork.reapply_after_rebuild!(host) if defined?(Artwork)
        Constraints.ensure_module_on_floor!(host)
      rescue StandardError => e
        puts "[ISOframe] handle_table_erased! failed: #{e.message}"
      end

      # --- SKP load / attach transform --------------------------------------

      def keyboard_definition!(model, entry)
        defn_name = entry[:defn_name].to_s
        existing = model.definitions[defn_name]
        return existing if existing && !existing.image? && existing.entities.size > 0

        path = MeshImport.model_path(entry[:skp_file] || SKP_KEYBOARD)
        raise "Missing bundled SKP: #{File.basename(path)}" unless File.file?(path)

        root = ensure_skp_imported!(model, path)
        kb_src, kb_inst, how = resolve_keyboard_source(model, root)
        unless kb_src || kb_inst
          sample = sample_skp_def_names(model)
          raise 'SKP has no keyboard table definition/instance ' \
                "(looked for Keyboard Attachment wrap / keyboard attachment). " \
                "Defs sample: #{sample}"
        end

        local = discover_attach_local(root, model, kb_src, kb_inst)
        local = apply_keyboard_orientation_correction(local)
        puts "[ISOframe] Keyboard source=#{how}; attach local origin mm: " \
             "#{(local.origin.x.to_f / 1.mm).round(1)}, " \
             "#{(local.origin.y.to_f / 1.mm).round(1)}, " \
             "#{(local.origin.z.to_f / 1.mm).round(1)}; " \
             "up·Z=#{local.zaxis.dot(Geom::Vector3d.new(0, 0, 1)).round(3)}"

        defn = existing || model.definitions.add(defn_name)
        defn.entities.clear! if defn.entities.size > 0

        if kb_src
          # Bake SKP attachment component at the module-local attach pose.
          inst = defn.entities.add_instance(kb_src, local)
          begin
            inst.explode if inst.respond_to?(:explode)
          rescue StandardError => e
            puts "[ISOframe] keyboard explode skipped: #{e.message}"
          end
        elsif kb_inst.is_a?(Sketchup::Group)
          # Copy group contents already transformed into Wave-local via local.
          copy_entities_transformed!(kb_inst.entities, defn.entities, local)
        else
          raise 'Keyboard source unresolved after match'
        end

        # If bake still empty, gather loose SKP parts (beams/base/wrap/…).
        if defn.entities.size == 0
          baked = bake_keyboard_parts_from_skp!(defn, root, model, local)
          puts "[ISOframe] Keyboard parts bake count=#{baked}"
        end
        raise 'Baked keyboard definition is empty' if defn.entities.size == 0

        tag_table_graphic_groups!(defn, entry[:graphic_group])
        ensure_table_graphic_group!(defn, entry[:graphic_group])
        # Pose is baked into the definition → place sibling at host.transformation.
        cache_attach_local!(model, Geom::Transformation.new)
        defn
      end

      # Prefer: (1) ComponentDefinition matching wrap/attach names,
      # (2) ComponentInstance/Group named "keyboard attachment" in the SKP,
      # (3) definition of that instance.
      # Returns [defn_or_nil, instance_or_group_or_nil, how_string]
      def resolve_keyboard_source(model, root)
        # 1) Definition by broadened name (wrap / table attachment / …).
        wrap = find_definition_by_name(model, KB_WRAP_RE)
        return [wrap, nil, "def:#{wrap.name}"] if wrap

        by_def = find_definition_by_name(model, KB_DEF_RE)
        # Prefer wrap-like over tiny part defs (base/lip/top).
        if by_def && !part_only_definition?(by_def)
          return [by_def, nil, "def:#{by_def.name}"]
        end

        # 2) Instance / group named keyboard attachment inside loaded SKP.
        ent = find_keyboard_entity(root)
        if ent.nil?
          model.definitions.each do |d|
            next if d.image?
            ent = find_keyboard_entity_in_entities(d.entities, 0)
            break if ent
          end
        end

        if ent.is_a?(Sketchup::ComponentInstance)
          return [ent.definition, ent, "inst:#{ent.name}/#{ent.definition.name}"]
        elsif ent.is_a?(Sketchup::Group)
          return [nil, ent, "group:#{ent.name}"]
        end

        # 3) Last: any KB_DEF_RE def even if part-like (better than nothing).
        return [by_def, nil, "def-fallback:#{by_def.name}"] if by_def

        [nil, nil, 'none']
      end

      def part_only_definition?(defn)
        n = defn.name.to_s
        return true if n =~ /keyboard\s*(base|lip|top)/i
        return true if n =~ /table\s*attachment\s*keyboard\s*(base|top)/i
        return true if n =~ /\b763\b|beam\s*straight|t-?box|table\s*post|adjustable\s*foot/i
        # Tiny entity count often means a single extrusion, not the full desk.
        begin
          return true if defn.entities.size > 0 && defn.entities.size < 3 && n !~ KB_WRAP_RE
        rescue StandardError
          nil
        end
        false
      end

      def find_keyboard_entity(root)
        return nil unless root && root.valid?
        find_keyboard_entity_in_entities(root.entities, 0)
      end

      def find_keyboard_entity_in_entities(entities, depth)
        return nil if entities.nil? || depth > 6
        entities.each do |e|
          if e.is_a?(Sketchup::ComponentInstance)
            iname = e.name.to_s
            dname = e.definition.name.to_s
            if iname =~ KB_INSTANCE_RE || dname =~ KB_WRAP_RE || dname =~ KB_DEF_RE
              return e unless part_only_definition?(e.definition)
            end
          elsif e.is_a?(Sketchup::Group)
            return e if e.name.to_s =~ KB_INSTANCE_RE || e.name.to_s =~ KB_WRAP_RE
          end
        end
        entities.grep(Sketchup::Group).each do |g|
          found = find_keyboard_entity_in_entities(g.entities, depth + 1)
          return found if found
        end
        entities.grep(Sketchup::ComponentInstance).each do |ci|
          next if wave_definition_name?(ci.definition.name.to_s)
          found = find_keyboard_entity_in_entities(ci.definition.entities, depth + 1)
          return found if found
        end
        nil
      end

      def sample_skp_def_names(model)
        names = []
        model.definitions.each do |d|
          next if d.image?
          n = d.name.to_s
          next if n.empty?
          names << n if n =~ /keyboard|attach|wrap|beam|763|t-?box|table/i
          break if names.size >= 12
        end
        names.empty? ? '(none matched keyboard/attach)' : names.join(' | ')
      rescue StandardError
        '(unavailable)'
      end

      def copy_entities_transformed!(src_entities, dst_entities, tr)
        return 0 unless src_entities && dst_entities
        count = 0
        src_entities.each do |e|
          if e.is_a?(Sketchup::ComponentInstance)
            dst_entities.add_instance(e.definition, tr * e.transformation)
            count += 1
          elsif e.is_a?(Sketchup::Group)
            # Instance a temporary def of the group contents, then explode.
            # Simpler: recurse with composed transform.
            count += copy_entities_transformed!(e.entities, dst_entities, tr * e.transformation)
          end
        end
        count
      rescue StandardError => e
        puts "[ISOframe] copy_entities_transformed! failed: #{e.message}"
        count
      end

      # Gather loose table parts from the SKP (beams, wrap, base, …) into bake def.
      def bake_keyboard_parts_from_skp!(defn, root, model, local_hint)
        wave, _kb = find_paired_wave_and_keyboard(root, nil)
        wave_tr = wave ? wave.transformation : Geom::Transformation.new
        count = 0
        visit = lambda do |entities, parent_tr, depth|
          return if entities.nil? || depth > 6
          entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
            name = e.name.to_s
            dname = e.respond_to?(:definition) ? e.definition.name.to_s : ''
            label = "#{name} #{dname}"
            if label =~ KEEP_PART_RE && label !~ SKIP_PART_RE
              part_tr = parent_tr * e.transformation
              # Into Wave-local, then apply local_hint if identity discovery.
              to_wave = wave_tr.inverse * part_tr
              if e.is_a?(Sketchup::ComponentInstance)
                defn.entities.add_instance(e.definition, to_wave)
                count += 1
              end
            end
            if e.is_a?(Sketchup::Group)
              visit.call(e.entities, parent_tr * e.transformation, depth + 1)
            elsif e.is_a?(Sketchup::ComponentInstance) && !wave_definition_name?(dname)
              # Don't descend into the whole Wave solid; do descend into wrap-like.
              if dname =~ KB_DEF_RE || name =~ KB_INSTANCE_RE
                visit.call(e.definition.entities, parent_tr * e.transformation, depth + 1)
              end
            end
          end
        end
        visit.call(root.entities, Geom::Transformation.new, 0) if root && root.valid?
        # Also scan model definitions' top entities once (imported SKP may nest oddly).
        if count == 0
          model.definitions.each do |d|
            next if d.image?
            next unless skp_root_name?(d.name) || d.name.to_s =~ KB_DEF_RE
            visit.call(d.entities, Geom::Transformation.new, 0)
          end
        end
        count
      rescue StandardError => e
        puts "[ISOframe] bake_keyboard_parts_from_skp! failed: #{e.message}"
        0
      end

      # Local transform of baked def relative to host (identity — pose baked in).
      def attach_local_transform(model, entry)
        keyboard_definition!(model, entry) # ensure baked
        @attach_local_by_model ||= {}
        @attach_local_by_model[model.object_id] || Geom::Transformation.new
      end

      def cache_attach_local!(model, tr)
        @attach_local_by_model ||= {}
        @attach_local_by_model[model.object_id] = tr
      end

      # Orientation correction about the attach origin (Wave-local).
      # Order (Richard):
      #   v0.1.54 (1) 90° CW looking from the right → −90° about +X
      #   v0.1.54 (2) 180° looking from above → +180° about +Z
      #   v0.1.55 (3) 180° looking from either side → +180° about +X
      #     (flips counter from under-floor / upside-down to upright on top)
      # Translation preserved (position offsets still deferred).
      def apply_keyboard_orientation_correction(local)
        origin = local.origin
        x_axis = Geom::Vector3d.new(1, 0, 0)
        z_axis = Geom::Vector3d.new(0, 0, 1)
        r_from_right = Geom::Transformation.rotation(
          origin, x_axis, -90.0 * Math::PI / 180.0
        )
        r_from_above = Geom::Transformation.rotation(
          origin, z_axis, 180.0 * Math::PI / 180.0
        )
        r_side_flip = Geom::Transformation.rotation(
          origin, x_axis, 180.0 * Math::PI / 180.0
        )
        r_side_flip * r_from_above * r_from_right * local
      end

      def ensure_skp_imported!(model, path)
        @skp_root_by_path ||= {}
        cached = @skp_root_by_path[path]
        return cached if cached && cached.valid?

        # Always load from the bundled path. SketchUp reuses an existing def for
        # the same file; do NOT trust a name-only match (stale/empty root from a
        # prior failed import would skip the real Keyboard_with_Extension.skp).
        begin
          root = model.definitions.load(path)
        rescue StandardError => e
          raise "Failed to load #{File.basename(path)}: #{e.message}"
        end
        raise "definitions.load returned nil for #{File.basename(path)}" unless root
        @skp_root_by_path[path] = root
        root
      end

      def skp_root_name?(name)
        n = name.to_s
        n =~ /Keyboard_with_Extension/i ||
          n =~ /keyboard.with.extension/i ||
          n =~ /Keyboard_Extension_Module/i ||
          n =~ /keyboard.extension.module/i
      end

      def find_definition_by_name(model, pattern)
        # Prefer the best match (wrap > full attach > first hit). DefinitionList
        # may not implement Enumerable#find reliably across SU versions.
        best = nil
        best_score = -1
        model.definitions.each do |d|
          next if d.respond_to?(:image?) && d.image?
          n = d.name.to_s
          next unless n =~ pattern
          score = 0
          score += 100 if n =~ KB_WRAP_RE
          score += 40 if n =~ KB_INSTANCE_RE
          score += 20 if n =~ /wrap/i
          score -= 50 if part_only_definition?(d)
          if score > best_score
            best = d
            best_score = score
          end
        end
        best
      end

      # Discover keyboard-attachment pose in Wave-module-local space from the SKP.
      # Prefer same-parent Wave Starter/Extension + keyboard attachment pair.
      def discover_attach_local(root, model, kb_src, kb_inst = nil)
        candidates = []

        # If we already resolved a concrete instance/group, pair it with nearest Wave.
        if kb_inst && kb_inst.respond_to?(:transformation)
          wave_near = nearest_wave_to_entity(root, model, kb_inst)
          if wave_near
            candidates << (wave_near.transformation.inverse * kb_inst.transformation)
          end
        end

        wave_inst, kb_found = find_paired_wave_and_keyboard(root, kb_src)
        if wave_inst && kb_found
          candidates << (wave_inst.transformation.inverse * kb_found.transformation)
        end

        # Search every definition (and nested groups) for same-parent pairs.
        model.definitions.each do |defn|
          next if defn.image?
          collect_pair_locals!(defn.entities, kb_src, candidates, Geom::Transformation.new)
        end

        candidates.each do |local|
          return local if attach_local_plausible?(local, kb_src)
        end

        # Fallback: upright + bay-centered (Wave hinge origin, graphic +Y).
        # Used only when SKP pair discovery fails plausible checks.
        fallback = bay_center_upright_fallback(kb_src)
        if attach_local_plausible?(fallback, kb_src)
          puts '[ISOframe] Keyboard attach: using bay-center upright fallback'
          return fallback
        end

        puts '[ISOframe] Warning: using identity attach for keyboard SKP'
        Geom::Transformation.new
      end

      def nearest_wave_to_entity(root, model, ent)
        waves = []
        gather_waves = lambda do |entities, depth|
          return if entities.nil? || depth > 6
          entities.each do |e|
            if e.is_a?(Sketchup::ComponentInstance) && wave_definition_name?(e.definition.name.to_s)
              waves << e
            elsif e.is_a?(Sketchup::Group)
              gather_waves.call(e.entities, depth + 1)
            elsif e.is_a?(Sketchup::ComponentInstance)
              gather_waves.call(e.definition.entities, depth + 1)
            end
          end
        end
        gather_waves.call(root.entities, 0) if root && root.valid?
        if waves.empty?
          model.definitions.each do |d|
            next if d.image?
            gather_waves.call(d.entities, 0)
          end
        end
        return nil if waves.empty?
        origin = ent.transformation.origin
        waves.min_by do |w|
          dx = w.transformation.origin.x - origin.x
          dy = w.transformation.origin.y - origin.y
          dz = w.transformation.origin.z - origin.z
          dx * dx + dy * dy + dz * dz
        end
      rescue StandardError
        nil
      end

      def collect_pair_locals!(entities, kb_src, out, parent_tr, depth = 0)
        return if entities.nil? || depth > 6
        waves = []
        keyboards = []

        entities.each do |e|
          if e.is_a?(Sketchup::ComponentInstance)
            dname = e.definition.name.to_s
            iname = e.name.to_s
            if wave_definition_name?(dname)
              waves << e
            elsif kb_src && e.definition == kb_src
              keyboards << e
            elsif keyboard_entity_name?(iname, dname)
              keyboards << e unless part_only_definition?(e.definition)
            end
            # Descend into nested instances (world = parent * child).
            collect_pair_locals!(
              e.definition.entities, kb_src, out,
              parent_tr * e.transformation, depth + 1
            )
          elsif e.is_a?(Sketchup::Group)
            if e.name.to_s =~ KB_INSTANCE_RE || e.name.to_s =~ KB_WRAP_RE
              keyboards << e
            end
            collect_pair_locals!(
              e.entities, kb_src, out,
              parent_tr * e.transformation, depth + 1
            )
          end
        end

        return if keyboards.empty? || waves.empty?
        kb = keyboards.first
        wave = waves.min_by do |w|
          dx = w.transformation.origin.x - kb.transformation.origin.x
          dy = w.transformation.origin.y - kb.transformation.origin.y
          dz = w.transformation.origin.z - kb.transformation.origin.z
          dx * dx + dy * dy + dz * dz
        end
        # Same-parent relative (instance transforms share this entities space).
        out << (wave.transformation.inverse * kb.transformation)
      rescue StandardError
        nil
      end

      def keyboard_entity_name?(iname, dname)
        label = "#{iname} #{dname}"
        return true if iname.to_s =~ KB_INSTANCE_RE
        return true if dname.to_s =~ KB_WRAP_RE
        return true if dname.to_s =~ KB_DEF_RE
        label =~ KB_INSTANCE_RE
      end

      def find_paired_wave_and_keyboard(root, kb_src)
        return [nil, nil] unless root && root.valid?
        find_pair_in_entities(root.entities, kb_src)
      end

      def find_pair_in_entities(entities, kb_src, depth = 0)
        return [nil, nil] unless entities && depth <= 6
        waves = []
        keyboards = []

        entities.each do |e|
          if e.is_a?(Sketchup::ComponentInstance)
            dname = e.definition.name.to_s
            iname = e.name.to_s
            if wave_definition_name?(dname)
              waves << e
            elsif kb_src && e.definition == kb_src
              keyboards << e
            elsif keyboard_entity_name?(iname, dname)
              keyboards << e unless part_only_definition?(e.definition)
            end
          elsif e.is_a?(Sketchup::Group)
            if e.name.to_s =~ KB_INSTANCE_RE || e.name.to_s =~ KB_WRAP_RE
              keyboards << e
            end
          end
        end

        entities.grep(Sketchup::Group).each do |g|
          w, k = find_pair_in_entities(g.entities, kb_src, depth + 1)
          return [w, k] if w && k
        end

        # One level into component instances that are not Wave/keyboard.
        entities.grep(Sketchup::ComponentInstance).each do |ci|
          dname = ci.definition.name.to_s
          iname = ci.name.to_s
          next if wave_definition_name?(dname) || keyboard_entity_name?(iname, dname)
          w, k = find_pair_in_entities(ci.definition.entities, kb_src, depth + 1)
          return [w, k] if w && k
        end

        return [nil, nil] if keyboards.empty?
        kb = keyboards.first
        wave = waves.min_by do |w|
          dx = w.transformation.origin.x - kb.transformation.origin.x
          dy = w.transformation.origin.y - kb.transformation.origin.y
          dz = w.transformation.origin.z - kb.transformation.origin.z
          dx * dx + dy * dy + dz * dz
        end
        [wave, kb]
      end

      def wave_definition_name?(name)
        n = name.to_s
        n =~ /ISOframe Wave Starter/i || n =~ /ISOframe Wave Extension/i
      end

      # Sanity: relative pose should put table near the bay (not metres away / tipped).
      def attach_local_plausible?(tr, kb_src)
        return false unless tr
        o = tr.origin
        # Origin within ~1.5 m of module origin (SketchUp inches).
        return false if Math.sqrt(o.x * o.x + o.y * o.y + o.z * o.z) > 1500.mm
        # Z axis of table should be roughly world/module up (|z·up| > 0.5).
        up_dot = tr.zaxis.dot(Geom::Vector3d.new(0, 0, 1)).abs
        return false if up_dot < 0.5
        true
      rescue StandardError
        false
      end

      # Last-resort pose: identity rotation + translate to bay center on +Y front.
      # Matches Wave hinge-origin / graphic-+Y convention when the SKP attachment
      # is authored centered on the bay (common in Keyboard_with_Extension.skp).
      def bay_center_upright_fallback(kb_src)
        ox = FALLBACK_BAY_CENTER_MM.mm
        oy = 0.0
        oz = 0.0
        begin
          bb = kb_src.bounds if kb_src && kb_src.respond_to?(:bounds)
          if bb
            # If def is already hinge-aligned (min.x near 0, max.x ~ bay), keep ox=0.
            min_x = bb.min.x
            max_x = bb.max.x
            width = max_x - min_x
            if width > 500.mm && min_x > -50.mm && min_x < 50.mm
              ox = 0.0
            elsif width > 500.mm && (min_x + max_x).abs < 100.mm
              # Centered on 0 → shift to hinge bay center.
              ox = FALLBACK_BAY_CENTER_MM.mm
            end
            # Prefer keeping Z at 0 (feet on floor in module space).
            oz = 0.0
          end
        rescue StandardError
          nil
        end
        Geom::Transformation.translation(Geom::Vector3d.new(ox, oy, oz))
      end

      # Rename / tag under-table graphic groups so Artwork can paint them
      # without touching wall GraphicHint / wallpaper rules on Wave modules.
      def tag_table_graphic_groups!(defn, stable_name)
        return unless defn && defn.valid?
        name = (stable_name || 'TableGraphicHint').to_s
        walk_tag_graphics!(defn.entities, name, 0)
      end

      def walk_tag_graphics!(entities, stable_name, depth)
        return if entities.nil? || depth > 8
        entities.each do |e|
          if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            ename = e.name.to_s
            dname = e.respond_to?(:definition) ? e.definition.name.to_s : ''
            # After explode, GraphicHint often sits at depth 0 of the baked def —
            # do not require depth > 0 (that skipped every top-level SKP hint).
            if table_graphic_name?(ename, dname)
              e.name = stable_name if e.respond_to?(:name=)
            end
            if e.is_a?(Sketchup::Group)
              walk_tag_graphics!(e.entities, stable_name, depth + 1)
            else
              walk_tag_graphics!(e.definition.entities, stable_name, depth + 1)
            end
          end
        end
      rescue StandardError
        nil
      end

      def table_graphic_name?(iname, dname)
        n = "#{iname} #{dname}"
        !!(n =~ TABLE_GRAPHIC_RE || n =~ TABLE_GRAPHIC_FIND_RE)
      end

      # Groups + component instances Artwork can paint (SKP GraphicHint, etc.).
      def table_graphic_groups(defn)
        return [] unless defn && defn.valid?
        found = []
        collect_table_graphic_entities!(defn.entities, found, 0)
        found
      end

      def collect_table_graphic_entities!(entities, out, depth)
        return if entities.nil? || depth > 8
        entities.each do |e|
          if e.is_a?(Sketchup::Group)
            next unless e.valid?
            iname = e.name.to_s
            if table_graphic_name?(iname, '')
              out << e
            end
            collect_table_graphic_entities!(e.entities, out, depth + 1)
          elsif e.is_a?(Sketchup::ComponentInstance)
            next unless e.valid?
            iname = e.name.to_s
            dname = e.definition.name.to_s
            if table_graphic_name?(iname, dname)
              out << e
            end
            collect_table_graphic_entities!(e.definition.entities, out, depth + 1)
          end
        end
      end

      # Bake + Apply time: tag SKP names, then create TableGraphicHint if still missing.
      def ensure_table_graphic_group!(defn, stable_name = 'TableGraphicHint')
        return nil unless defn && defn.valid?
        name = (stable_name || 'TableGraphicHint').to_s
        tag_table_graphic_groups!(defn, name)
        existing = table_graphic_groups(defn)
        return existing.first if existing.any?

        created = create_table_graphic_hint_group!(defn, name)
        puts "[ISOframe] ensure_table_graphic_group! created=#{!created.nil?}"
        created
      rescue StandardError => e
        puts "[ISOframe] ensure_table_graphic_group! failed: #{e.message}"
        nil
      end

      # Last resort: group the largest vertical-ish faces into TableGraphicHint so
      # Apply Table Artwork has a paint target when SKP names were lost on explode.
      def create_table_graphic_hint_group!(defn, stable_name)
        faces = []
        gather_faces = lambda do |entities, depth|
          return if entities.nil? || depth > 6
          entities.each do |e|
            if e.is_a?(Sketchup::Face) && e.valid?
              faces << e
            elsif e.is_a?(Sketchup::Group)
              gather_faces.call(e.entities, depth + 1)
            elsif e.is_a?(Sketchup::ComponentInstance)
              gather_faces.call(e.definition.entities, depth + 1)
            end
          end
        end
        gather_faces.call(defn.entities, 0)

        # Prefer large non-horizontal faces (apron / under-table panel).
        candidates = faces.select do |f|
          next false unless f.valid?
          n = f.normal
          next false if n.z.abs >= 0.85
          begin
            (f.area.to_f * 25.4 * 25.4) >= 400.0
          rescue StandardError
            false
          end
        end
        # Only group faces that still live directly in the baked def (movable).
        direct = candidates.select { |f| f.parent == defn.entities }
        direct = faces.select { |f| f.valid? && f.parent == defn.entities } if direct.empty?
        return nil if direct.empty?

        group = defn.entities.add_group(direct)
        group.name = stable_name.to_s
        group
      rescue StandardError => e
        puts "[ISOframe] create_table_graphic_hint_group! failed: #{e.message}"
        nil
      end

      def collect_named_groups!(entities, pattern, out, depth)
        return if entities.nil? || depth > 8
        entities.each do |e|
          if e.is_a?(Sketchup::Group)
            out << e if e.valid? && e.name.to_s =~ pattern
            collect_named_groups!(e.entities, pattern, out, depth + 1)
          elsif e.is_a?(Sketchup::ComponentInstance)
            collect_named_groups!(e.definition.entities, pattern, out, depth + 1)
          end
        end
      end

      # Install erase watcher so Delete on the table does not require menu detach.
      def install_erase_observer!(model)
        return unless model
        @erase_observers ||= {}
        return if @erase_observers[model.object_id]
        obs = TableEraseObserver.new
        model.entities.add_observer(obs)
        @erase_observers[model.object_id] = obs
      end

      class TableEraseObserver < Sketchup::EntitiesObserver
        def initialize
          @host_by_eid = {}
        end

        def onElementAdded(_entities, entity)
          return unless Tables.table_instance?(entity)
          mid = Attributes.get(entity, Constants::KEY_TABLE_HOST).to_s
          @host_by_eid[entity.entityID] = mid unless mid.empty?
        end

        def onElementModified(_entities, entity)
          return unless entity && entity.valid?
          # Keep sibling table glued to host when host moves (XY free, Z locked).
          if SelectionUtil.wave_module?(entity) && Tables.table_on?(entity)
            Tables.reposition_table_for_host!(entity)
          end
        rescue StandardError
          nil
        end

        def onElementRemoved(_entities, entity_id)
          mid = @host_by_eid.delete(entity_id)
          return if mid.nil? || mid.empty?
          model = Sketchup.active_model
          return unless model
          # If a replacement table already exists for this host, do nothing.
          still = model.active_entities.grep(Sketchup::ComponentInstance).any? do |e|
            Tables.table_instance?(e) &&
              Attributes.get(e, Constants::KEY_TABLE_HOST).to_s == mid
          end
          return if still
          Tables.handle_table_erased!(model, mid)
        rescue StandardError
          nil
        end
      end
    end
  end
end
