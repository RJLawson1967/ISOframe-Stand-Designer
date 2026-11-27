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
# v0.1.56: placement offsets (front view: 19.5 mm closer = −Y, 19.6 mm left = +X).
# Artwork root cause: SKP GraphicHint groups belong only to Wave modules — the
# under-table apron is "exhibit and wave keyboard lip". Match lip/top; ensure
# must not rely on top-level faces after explode of nested components.
# v0.1.57: LOCK position offsets + orientation. Stop synthesizing flat artwork
# panels; purge any prior zero-thickness TableGraphicHint planes; paint the
# real curved keyboard lip/apron faces only.
# v0.1.58: Apply Table Artwork still failed — explode+rename wiped searchable lip
# names (Groups lose "keyboard lip"). Do NOT explode the wrap (keep nested lip
# ComponentInstance). Do NOT require a named graphic group at apply — paint
# apron faces in place (lip if present, else non-post faces of the bake).
# v0.1.59: apron-only + continuous UV. v0.1.58 painted ~146k faces (whole wrap /
# character mesh) with per-face tiling and hit the 15mm tabletop edge. Paint only
# keyboard-lip apron faces under the top; one developed UV across the curve.
# v0.1.60: v0.1.59 found ZERO apron faces — lip SKP is the apron alone (top is a
# separate "keyboard top"). Per-face Z-span≤17mm rejected tessellated apron
# facets. Select lip faces excluding only near-horizontals; top/edge stay on
# the top component (never painted).
# v0.1.61: live apply still empty — lip-local normals / missing lip / no fallback.
# Resolve lip with path transform into bake-root (Z-up); never return empty when
# lip (or safe apron container) has faces; paint continuous UV; never whole wrap.
# v0.1.62: v0.1.61 spilled onto tabletop top/edge and 37mm rear beams. Paint ONLY
# keyboard lip apron; exclude every keyboard-top face and beams/posts/frame.
# v0.1.63: live bake has lip=NONE — SKP children are unnamed Boss-Extrude /
# Cut-Extrude / Fillet defs. Find apron by geometry when the lip name is gone;
# still never paint tabletop or 37mm beams/posts.
# Also: keyboard table is a sibling but must host-follow — when Wave flex moves
# the host S/E (or chain stick modules), reposition table = host * locked local.
# v0.1.65: Richard's paint target is Keyboard_table_graphic_wrap.skp —
# "Graphic Keyboard Attachment (Rolable)" (3-panel curved wrap). Paint FRONT
# only + continuous UV + soft/hide edges. Lip/Boss-Extrude is no longer primary.
# v0.1.66: v0.1.65 reported 2500 faces painted but texture invisible — cylindrical
# UV + hide-all-edges + loose face dump. Use planar front UV (wall-style), paint
# correct face side, soft+smooth without hide.
# v0.1.67: still “2500 faces” = apron fallback. Stop fallback. Reuse wall
# ensure_bay_material + paint_front_face path; make_unique nested defs; prove
# face.material.texture non-nil.
# v0.1.68: live bake has only Boss-Extrude children — Graphic Keyboard wrap is
# NEVER in Keyboard_with_Extension bake. Always load Keyboard_table_graphic_wrap.skp
# and instance it under the top (apron front) on place + apply.
# v0.1.69: wrap SKP must ship inside plugin models/; resolve via __FILE__ next to
# tables.rb with logged fallbacks — v0.1.68 zip omitted the SKP so instance failed.
# v0.1.70: after load, dump ALL definition names; match broadly (DC truncates at ^
# to "Keyboard Attachment wrap", plus GraphicHint / keyboard attachment / Rolable).
# Place must always succeed — geometry/root fallback if name match fails.
# v0.1.71: Place path reverts to table-SKP-only (no place-time wrap SKP load /
# broad-match / root fallback that spawned a distant orphan wrap). Apply Table
# Artwork is untouched and still calls ensure_graphic_wrap_target! on apply.
# Also: Semi-circular + Square table attachments — same S+E host attach, offsets,
# orientation, flexilink delete, and host-follow as Keyboard; shape SKP only differs.

module ISOframe
  module StandDesigner
    module Tables
      module_function

      REGISTRY = {
        'keyboard' => {
          kind: 'keyboard',
          label: 'Keyboard Table',
          straight_only: true,
          skp_file: 'Keyboard_with_Extension.skp',
          # Fresh name so dealers drop any cached v43–v70 bake.
          defn_name: 'ISOframe Table Keyboard SKP v71',
          instance_name: 'ISOframe Keyboard Table',
          graphic_group: 'TableGraphicHint'
        },
        'semi_circular' => {
          kind: 'semi_circular',
          label: 'Semi-circular table attachment',
          straight_only: true,
          skp_file: 'Semi-circular_Table_Attachment.skp',
          defn_name: 'ISOframe Table Semi-circular SKP v71',
          instance_name: 'ISOframe Semi-circular Table',
          graphic_group: 'TableGraphicHint'
        },
        'square' => {
          kind: 'square',
          label: 'Square Table attachment',
          straight_only: true,
          skp_file: 'Square_Table_Attachment.skp',
          defn_name: 'ISOframe Table Square SKP v71',
          instance_name: 'ISOframe Square Table',
          graphic_group: 'TableGraphicHint'
        }
      }.freeze

      # Dedicated graphic-wrap SKP (Richard 2026-11-26) — paint surface for table artwork.
      SKP_GRAPHIC_WRAP = 'Keyboard_table_graphic_wrap.skp'
      # Broad match — SketchUp DC often exposes only the part before ^
      # ("Keyboard Attachment wrap"), not the full "...Graphic Keyboard...(Rolable)".
      # Real names dumped from Keyboard_table_graphic_wrap.skp (model.dat):
      #   Keyboard Attachment wrap^Keyboard table attachment_Graphic Keyboard Attachment (Rolable)
      #   GraphicHint
      #   keyboard attachment
      GRAPHIC_WRAP_RE = /
        graphic\s*keyboard|
        keyboard\s*table\s*attachment_graphic|
        graphic\s*hint|
        \bgraphichint\b|
        rolab(?:le|ble)|
        keyboard\s*attachment\s*wrap|
        attachment\s*wrap|
        \bkeyboard\s*attachment\b
      /ix
      # Structural / non-paint defs inside the wrap SKP — never pick these.
      GRAPHIC_WRAP_EXCLUDE_RE = /
        \Aboss-extrude|\Acut-extrude|\Afillet|\Aextrude-thin|
        keyboard\s*lip|keyboard\s*top|keyboard\s*base|
        table\s*post|beam\s*straight|adjustable\s*foot|
        floorspace|flood\s*light|wave\s*starter|wave\s*extension|
        flexibeam|basesupport|postnew|\bpost[ab]\b|
        \bsree\b|led\s*flood|t-box
      /ix

      # Geometry thresholds for nameless SolidWorks feature parts (mm).
      APRON_MIN_HEIGHT_MM = 25.0
      APRON_MIN_FACES = 3
      BEAM_CROSS_MM = 50.0
      BEAM_MIN_LENGTH_MM = 200.0
      TABLETOP_MAX_HEIGHT_MM = 25.0
      TABLETOP_MIN_PLAN_MM = 200.0

      # LOCKED v0.1.56 — do not change unless Richard asks.
      # Wave-local placement nudge after orientation bake (identity pose in def).
      # Looking from the front of the starter (graphic +Y / viewer looks −Y):
      #   closer to module = −Y; viewer left = +X.
      PLACE_CLOSER_MM = 19.5
      PLACE_LEFT_MM = 19.6
      # Tabletop thickness (Richard) — apron is under this; edge faces ~this tall.
      TABLETOP_THICKNESS_MM = 15.0
      # Attribute on synthetic zero-thickness panels (v0.1.56 mistake) for purge.
      KEY_SYNTHETIC_TABLE_GRAPHIC = 'isoframe_synthetic_table_graphic'

      SKP_KEYBOARD = 'Keyboard_with_Extension.skp'
      # Attachment assembly names across Keyboard / Semi-circular / Square SKPs:
      #   "Keyboard Attachment wrap" / "keyboard attachment"
      #   "Semicircle Attachment Wrap" / "Semicircle table attachment"
      #   "Square Attachment Wrap" / "square attachement" (SKP typo kept)
      # Do NOT require the shape word immediately before "attachment".
      KB_DEF_RE = /
        keyboard.*attach|attach.*keyboard|
        semicircle.*attach|semi[-\s]*circle.*attach|
        square.*attach|attach.*square
      /ix
      KB_INSTANCE_RE = /
        keyboard\s*(table\s*)?attachment|
        semicircle\s*(table\s*)?attachment|
        semi[-\s]*circular\s*(table\s*)?attachment|
        square\s*(table\s*)?attach
      /ix
      KB_WRAP_RE = /
        keyboard\s*attachment\s*wrap|
        semicircle\s*attachment\s*wrap|
        square\s*attachment\s*wrap
      /ix
      # Loose parts to gather if no single attachment component (v0.1.43-style fallback).
      KEEP_PART_RE = /
        keyboard|
        semicircle|
        semi[-\s]*circle|
        square|
        attachment\s*wrap|
        table\s*attachment|
        table\s*post|
        \b763\b|
        beam\s*straight|
        t-?box|
        (?:keyboard|semi\s*circle|semicircle|square)\s*(base|lip|top)|
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
      # Under-table graphic targets in Keyboard_with_Extension.skp:
      #   Primary apron: "exhibit and wave keyboard lip" (NOT Wave GraphicHint —
      #   those 16 GraphicHint groups are wall panels on starters/extensions).
      #   Also: keyboard top, DC "Graphic Keyboard Attachment (Rolable)", tag.
      TABLE_GRAPHIC_RE = /
        table\s*graphic\s*hint|
        graphic\s*hint|
        graphic\s*keyboard|
        table\s*graphic|
        keyboard\s*attachment\s*wrap|
        keyboard\s*lip|
        table\s*attachment\s*keyboard\s*(lip|top)|
        exhibit\s+and\s+wave\s+keyboard\s+lip|
        rolable
      /ix
      TABLE_GRAPHIC_FIND_RE = /
        TableGraphicHint|
        GraphicHint|
        Graphic\s*Keyboard|
        keyboard\s*lip|
        keyboard\s*top|
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
            "Select a straight Wave starter or extension, then #{label_for(type_key)}."
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

        type_key = entry[:kind].to_s
        type_key = 'keyboard' if type_key.empty?

        table_defn = keyboard_definition!(model, entry)
        local = attach_local_transform(model, entry)
        world_tr = host.transformation * local

        inst = model.active_entities.add_instance(table_defn, world_tr)
        inst.name = entry[:instance_name]
        Attributes.set(inst, Constants::KEY_TABLE_KIND, type_key.to_s)
        Attributes.set(inst, Constants::KEY_TABLE_HOST, mid.to_s)
        # Carry any prior table artwork path from host → new sibling.
        prior = Attributes.get(host, Constants::KEY_TABLE_ARTWORK_PATH, '').to_s
        Attributes.set(inst, Constants::KEY_TABLE_ARTWORK_PATH, prior) unless prior.empty?
        Artwork.reapply_table_instance!(inst) if defined?(Artwork) && !prior.empty?
        inst
      end

      def reposition_table_for_host!(host)
        return unless host && host.valid?
        return unless table_on?(host)
        table = find_table_instance_for_host(host)
        return unless table && table.valid?
        entry = REGISTRY[table_type(host)] || REGISTRY['keyboard']
        local = attach_local_transform(host.model, entry)
        # Locked offsets stay in `local`; world pose always tracks host.
        table.transformation = host.transformation * local
        table
      rescue StandardError => e
        puts "[ISOframe] reposition_table_for_host! failed: #{e.message}"
        nil
      end

      # After flex / chain stick moves: glue every listed host's keyboard table.
      def follow_hosts!(hosts)
        Array(hosts).each do |host|
          next unless host && host.valid?
          next unless SelectionUtil.wave_module?(host)
          next unless table_on?(host)
          reposition_table_for_host!(host)
        end
        nil
      rescue StandardError => e
        puts "[ISOframe] Tables.follow_hosts! failed: #{e.message}"
        nil
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

        skp_name = entry[:skp_file] || SKP_KEYBOARD
        path = MeshImport.model_path(skp_name)
        raise "Missing bundled SKP: #{File.basename(path)}" unless File.file?(path)

        root = ensure_skp_imported!(model, path)
        kb_src, kb_inst, how = resolve_keyboard_source(model, root)
        unless kb_src || kb_inst
          sample = sample_skp_def_names(model)
          raise "SKP has no table attachment definition/instance " \
                "(looked for Attachment wrap / table attachment in #{File.basename(path)}). " \
                "Defs sample: #{sample}"
        end

        local = discover_attach_local(root, model, kb_src, kb_inst)
        local = apply_keyboard_orientation_correction(local)
        puts "[ISOframe] Table source=#{how} skp=#{File.basename(path)}; attach local origin mm: " \
             "#{(local.origin.x.to_f / 1.mm).round(1)}, " \
             "#{(local.origin.y.to_f / 1.mm).round(1)}, " \
             "#{(local.origin.z.to_f / 1.mm).round(1)}; " \
             "up·Z=#{local.zaxis.dot(Geom::Vector3d.new(0, 0, 1)).round(3)}"

        defn = existing || model.definitions.add(defn_name)
        defn.entities.clear! if defn.entities.size > 0

        attach_label = entry[:instance_name].to_s.empty? ? 'ISOframe Table Attachment' : entry[:instance_name].to_s
        if kb_src
          # Keep the attachment as a nested instance (v0.1.58). Exploding DC wraps was
          # converting/renaming nested lip parts so Apply Artwork could not find
          # "keyboard lip". Pose stays on this instance transform.
          wrap_inst = defn.entities.add_instance(kb_src, local)
          wrap_inst.name = attach_label if wrap_inst.respond_to?(:name=)
        elsif kb_inst.is_a?(Sketchup::Group)
          # Copy group contents already transformed into Wave-local via local.
          copy_entities_transformed!(kb_inst.entities, defn.entities, local)
        elsif kb_inst.is_a?(Sketchup::ComponentInstance)
          wrap_inst = defn.entities.add_instance(kb_inst.definition, local * kb_inst.transformation)
          wrap_inst.name = attach_label if wrap_inst.respond_to?(:name=)
        else
          raise 'Table source unresolved after match'
        end

        # If bake still empty, gather loose SKP parts (beams/base/wrap/…).
        if defn.entities.size == 0
          baked = bake_keyboard_parts_from_skp!(defn, root, model, local)
          puts "[ISOframe] Table parts bake count=#{baked}"
        end
        raise 'Baked table definition is empty' if defn.entities.size == 0

        purge_synthetic_table_graphic_panels!(defn)
        # Attribute-tag only — do not rename lip (Groups would lose "keyboard lip").
        mark_table_graphic_targets!(defn)
        # v0.1.71: do NOT load/instance Keyboard_table_graphic_wrap.skp on Place.
        # v0.1.70 broad match + root fallback spawned a distant orphan wrap.
        # Apply Table Artwork still calls ensure_graphic_wrap_target! on apply only.
        dump = dump_baked_entity_names(defn.entities, 0)
        puts "[ISOframe] Table bake entities: #{dump}"
        lip = find_keyboard_lip_entity(defn.entities, 0)
        puts "[ISOframe] Table lip after bake=" \
             "#{lip ? "#{lip.class} name=#{lip.name} def=#{lip.respond_to?(:definition) ? lip.definition.name : '-'}" : 'NONE'}"
        # Pose on nested attachment instance; placement keeps Wave-local XY offset
        # (LOCKED v0.1.56) relative to the host — shared by Keyboard/Semi/Square.
        cache_attach_local!(model, placement_offset_transform)
        defn
      end

      # Wave-local translation: +X = viewer left from front, −Y = closer to module.
      def placement_offset_transform
        Geom::Transformation.translation(
          Geom::Vector3d.new(PLACE_LEFT_MM.mm, -PLACE_CLOSER_MM.mm, 0)
        )
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
        return true if n =~ /semi\s*circle\s*(base|lip|top)|semicircle\s*(base|lip|top)/i
        return true if n =~ /square\s*(base|lip|top)/i
        return true if n =~ /table\s*attachment\s*(keyboard|semicircle|semi\s*circle|square)\s*(base|top)/i
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

      # Local transform of baked def relative to host.
      # Orientation is baked into the definition; placement keeps Wave-local XY offset.
      def attach_local_transform(model, entry)
        keyboard_definition!(model, entry) # ensure baked
        @attach_local_by_model ||= {}
        @attach_local_by_model[model.object_id] || placement_offset_transform
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
          n =~ /keyboard.extension.module/i ||
          n =~ /Keyboard_table_graphic_wrap/i ||
          n =~ /keyboard.table.graphic.wrap/i ||
          n =~ /Semi-?circular_Table_Attachment/i ||
          n =~ /semi.?circular.?table.?attachment/i ||
          n =~ /Square_Table_Attachment/i ||
          n =~ /square.?table.?attachment/i
      end

      INSTANCED_WRAP_NAME = 'ISOframe Graphic Keyboard Wrap'

      # Broad paint-wrap name match (v0.1.70). DC may truncate at ^ so the live
      # def name is only "Keyboard Attachment wrap" — still a hit.
      def graphic_wrap_definition_name?(name)
        n = name.to_s
        return false if n.strip.empty?
        return true if n == INSTANCED_WRAP_NAME
        return false if n =~ GRAPHIC_WRAP_EXCLUDE_RE
        return true if n =~ GRAPHIC_WRAP_RE
        false
      end

      def graphic_wrap_paint_name?(iname, dname)
        return true if graphic_wrap_definition_name?(iname) || graphic_wrap_definition_name?(dname)
        return true if iname.to_s == INSTANCED_WRAP_NAME
        return false if lip_name?(iname, dname)
        return false if top_name?(iname, dname)
        n = "#{iname} #{dname}"
        return false if n =~ GRAPHIC_WRAP_EXCLUDE_RE
        return false if n =~ /\bsree\b|table\s*post|\b763\b|beam/i
        false
      end

      # Resolve Keyboard_table_graphic_wrap.skp — must live under
      # isoframe_stand_designer/models/ next to this file in the release zip.
      def graphic_wrap_skp_candidates
        here = File.dirname(File.expand_path(__FILE__)) # .../isoframe_stand_designer
        [
          File.join(here, 'models', SKP_GRAPHIC_WRAP),
          MeshImport.model_path(SKP_GRAPHIC_WRAP),
          File.expand_path(File.join(here, '..', 'isoframe_stand_designer', 'models', SKP_GRAPHIC_WRAP)),
          # Cloud-agent store media (dev only).
          File.expand_path(File.join(here, '..', '..', '..', '..', 'media', 'tables', SKP_GRAPHIC_WRAP))
        ].map { |p| File.expand_path(p) }.uniq
      end

      def graphic_wrap_skp_path
        tried = []
        graphic_wrap_skp_candidates.each do |p|
          ok = File.file?(p)
          tried << "#{ok ? 'HIT' : 'miss'} #{p}"
          if ok
            puts "[ISOframe] graphic wrap SKP path: #{p}"
            return p
          end
        end
        puts "[ISOframe] graphic wrap SKP NOT FOUND. Tried:\n  #{tried.join("\n  ")}"
        nil
      end

      def graphic_wrap_skp_path!
        path = graphic_wrap_skp_path
        return path if path
        raise "#{SKP_GRAPHIC_WRAP} not found next to the plugin. " \
              "Reinstall v0.1.70 zip (models/#{SKP_GRAPHIC_WRAP} must be present). " \
              "Tried:\n#{graphic_wrap_skp_candidates.join("\n")}"
      end

      # Dump every ComponentDefinition name after wrap SKP load (Ruby Console).
      def dump_model_definition_names!(model, tag)
        rows = []
        model.definitions.each do |d|
          next unless d && d.valid?
          next if d.respond_to?(:image?) && d.image?
          ents = d.entities
          faces = ents.grep(Sketchup::Face).size
          nested = ents.grep(Sketchup::Group).size + ents.grep(Sketchup::ComponentInstance).size
          hit = graphic_wrap_definition_name?(d.name)
          rows << "#{d.name.inspect} faces=#{faces} nested=#{nested} wrap_match=#{hit}"
        end
        puts "[ISOframe] #{tag} definitions (#{rows.size}):\n  #{rows.join("\n  ")}"
        rows
      rescue StandardError => e
        puts "[ISOframe] dump definitions failed: #{e.message}"
        []
      end

      # Find Graphic Keyboard / GraphicHint / Attachment wrap inside the table bake.
      def find_graphic_wrap_with_transform(entities, depth, tr)
        return nil if entities.nil? || depth > 12
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next unless e.valid?
          iname = e.name.to_s
          dname = def_name_of(e)
          local = tr * e.transformation
          return [e, local] if graphic_wrap_paint_name?(iname, dname)
          child = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          nested = find_graphic_wrap_with_transform(child, depth + 1, local)
          return nested if nested
        end
        nil
      end

      def score_wrap_definition(d)
        n = d.name.to_s
        return -1.0e9 if n =~ GRAPHIC_WRAP_EXCLUDE_RE
        ents = d.entities
        faces = ents.grep(Sketchup::Face).size
        nested = ents.grep(Sketchup::Group).size + ents.grep(Sketchup::ComponentInstance).size
        return -1.0e9 if faces.zero? && nested.zero?
        score = 0.0
        score += 80.0 if n =~ /rolab(?:le|ble)/i
        score += 70.0 if n =~ /graphic\s*keyboard/i
        score += 60.0 if n =~ /graphic\s*hint|\bgraphichint\b/i
        score += 55.0 if n =~ /keyboard\s*attachment\s*wrap|attachment\s*wrap/i
        score += 35.0 if n =~ /\bkeyboard\s*attachment\b/i
        score += 25.0 if graphic_wrap_definition_name?(n)
        score += [faces, 400].min * 0.05
        score += nested * 0.4
        begin
          bb = d.bounds
          unless bb.nil? || bb.empty?
            dx = (bb.max.x - bb.min.x).abs / 1.mm
            dy = (bb.max.y - bb.min.y).abs / 1.mm
            dz = (bb.max.z - bb.min.z).abs / 1.mm
            score += 20.0 if dz >= 40.0 && [dx, dy].min <= 100.0
            score -= 40.0 if dx > 2500.0 || dy > 2500.0
            score -= 20.0 if faces > 50_000 # character / huge mesh
          end
        rescue StandardError
          nil
        end
        score
      end

      # Best ComponentDefinition from loaded wrap SKP / model for paint geometry.
      def find_best_graphic_wrap_definition(model)
        best = nil
        best_score = -1.0
        model.definitions.each do |d|
          next unless d && d.valid?
          next if d.respond_to?(:image?) && d.image?
          n = d.name.to_s
          next unless graphic_wrap_definition_name?(n)
          score = score_wrap_definition(d)
          next if score < 0.0
          if score > best_score
            best_score = score
            best = d
          end
        end
        puts "[ISOframe] best wrap def=#{best ? best.name.inspect : 'NONE'} score=#{best_score.round(1)}"
        best
      end

      # Geometry fallback: best nested ComponentInstance def under loaded root.
      def pick_wrap_def_from_root(root)
        return nil unless root && root.valid?
        best = nil
        best_score = -1.0
        walk = lambda do |entities, depth|
          return if entities.nil? || depth > 10
          entities.each do |e|
            next unless e.is_a?(Sketchup::ComponentInstance) && e.valid?
            d = e.definition
            next unless d && d.valid?
            n = d.name.to_s
            iname = e.name.to_s
            unless graphic_wrap_definition_name?(n) || graphic_wrap_definition_name?(iname)
              # still score non-excluded nested defs as weak candidates
              if n !~ GRAPHIC_WRAP_EXCLUDE_RE && iname !~ GRAPHIC_WRAP_EXCLUDE_RE
                score = score_wrap_definition(d) - 15.0
                if score > best_score
                  best_score = score
                  best = d
                end
              end
            else
              score = score_wrap_definition(d)
              if score > best_score
                best_score = score
                best = d
              end
            end
            walk.call(d.entities, depth + 1)
          end
        end
        walk.call(root.entities, 0)
        # Also consider root itself if it looks like a wrap assembly.
        if graphic_wrap_definition_name?(root.name) || root.name.to_s =~ /graphic\s*wrap|keyboard/i
          score = score_wrap_definition(root)
          if score > best_score
            best_score = score
            best = root
          end
        end
        puts "[ISOframe] root-walk wrap def=#{best ? best.name.inspect : 'NONE'} score=#{best_score.round(1)}"
        best
      rescue StandardError => e
        puts "[ISOframe] pick_wrap_def_from_root failed: #{e.message}"
        nil
      end

      # Place wrap under keyboard top, apron-front (viewer side).
      def wrap_placement_transform_for_bake(table_defn, wrap_def)
        id = identity_transform
        wbb = wrap_def.bounds
        raise 'Wrap definition has empty bounds' if wbb.nil? || wbb.empty?

        wx0 = wbb.min.x
        wy0 = wbb.min.y
        wz0 = wbb.min.z
        wx1 = wbb.max.x
        wy1 = wbb.max.y
        wz1 = wbb.max.z
        wcx = (wx0 + wx1) * 0.5
        wcy = (wy0 + wy1) * 0.5
        # Prefer the face of the wrap with larger |Y| extent as "depth"; front = max Y in def.
        w_front_y = wy1
        w_top_z = wz1

        target = placement_anchor_under_top(table_defn)
        tx = target[:cx]
        ty = target[:front_y]
        tz = target[:under_z]

        # Move wrap so: center X → tx, front Y → ty, top Z → tz (just under top).
        Geom::Transformation.translation(
          Geom::Vector3d.new(tx - wcx, ty - w_front_y, tz - w_top_z)
        )
      rescue StandardError => e
        puts "[ISOframe] wrap pose fallback (#{e.message})"
        # Bay-ish apron front default in table-local space.
        Geom::Transformation.translation(
          Geom::Vector3d.new(Constants::GRAPHIC_BAY_MM.mm * 0.5, 0, 50.mm)
        )
      end

      def placement_anchor_under_top(table_defn)
        id = identity_transform
        top = find_keyboard_top_with_transform(table_defn.entities, 0, id)
        anchor = anchor_from_entity(top[0], top[1]) if top && top[0]
        return anchor if anchor

        geo = find_tabletop_like_container(table_defn)
        anchor = anchor_from_entity(geo[0], geo[1]) if geo && geo[0]
        return anchor if anchor

        {
          cx: Constants::GRAPHIC_BAY_MM.mm * 0.5,
          front_y: 0.0,
          under_z: 100.mm
        }
      end

      def anchor_from_entity(ent, tr)
        return nil unless ent && ent.valid?
        bb = ent.bounds
        return nil if bb.nil? || bb.empty?
        tr ||= identity_transform
        corners = [
          tr * Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
          tr * Geom::Point3d.new(bb.max.x, bb.min.y, bb.min.z),
          tr * Geom::Point3d.new(bb.min.x, bb.max.y, bb.min.z),
          tr * Geom::Point3d.new(bb.max.x, bb.max.y, bb.min.z),
          tr * Geom::Point3d.new(bb.min.x, bb.min.y, bb.max.z),
          tr * Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z)
        ]
        xs = corners.map(&:x)
        ys = corners.map(&:y)
        zs = corners.map(&:z)
        {
          cx: (xs.min + xs.max) * 0.5,
          front_y: ys.max,
          under_z: zs.min - 0.5.mm
        }
      rescue StandardError
        nil
      end

      # Always ensure wrap is in bake: find existing, else load SKP and instance.
      def ensure_graphic_wrap_target!(table_defn, model)
        return [nil, nil] unless table_defn && table_defn.valid? && model

        # 1) Already instanced / nested in this bake.
        hit = find_graphic_wrap_with_transform(table_defn.entities, 0, identity_transform)
        if hit && hit[0]
          mark_as_table_graphic!(hit[0])
          puts "[ISOframe] graphic wrap already in bake name=#{hit[0].name} def=#{def_name_of(hit[0])}"
          return hit
        end

        # 2) Load Keyboard_table_graphic_wrap.skp and instance into bake.
        path = graphic_wrap_skp_path!
        puts "[ISOframe] loading wrap SKP: #{path} (#{File.size(path)} bytes)"

        root = ensure_skp_imported!(model, path)
        dump_model_definition_names!(model, 'after wrap SKP load')

        gdef = find_best_graphic_wrap_definition(model)
        unless gdef
          if root && root.valid?
            nested = find_graphic_wrap_with_transform(root.entities, 0, identity_transform)
            if nested && nested[0].is_a?(Sketchup::ComponentInstance)
              gdef = nested[0].definition
              puts "[ISOframe] wrap from nested instance def=#{gdef.name.inspect}"
            elsif nested && nested[0].is_a?(Sketchup::Group)
              # Groups cannot be add_instance'd — keep searching.
              puts "[ISOframe] nested wrap hit is a Group name=#{nested[0].name.inspect}"
            end
          end
        end
        gdef = pick_wrap_def_from_root(root) if gdef.nil? || !gdef.valid?
        # Place MUST succeed: instance the loaded SKP root if nothing else matched.
        if gdef.nil? || !gdef.valid?
          gdef = root
          puts "[ISOframe] FALLBACK instancing wrap SKP root def=#{root.name.inspect}"
        end
        unless gdef && gdef.valid?
          raise "Loaded #{File.basename(path)} but got no usable definition. path=#{path}"
        end

        local = wrap_placement_transform_for_bake(table_defn, gdef)
        inst = table_defn.entities.add_instance(gdef, local)
        unless inst && inst.valid?
          raise "add_instance failed for wrap def=#{gdef.name} path=#{path}"
        end
        inst.name = INSTANCED_WRAP_NAME if inst.respond_to?(:name=)
        mark_as_table_graphic!(inst)
        begin
          inst.set_attribute('ISOframe', 'graphic_wrap_instanced', true)
        rescue StandardError
          nil
        end
        puts "[ISOframe] INSTANCED wrap from #{path} def=#{gdef.name.inspect} " \
             "origin=#{local.origin}"
        [inst, local]
      rescue StandardError => e
        puts "[ISOframe] ensure_graphic_wrap_target! failed: #{e.message}"
        raise
      end

      # make_unique wrap + nested CIs, then collect FRONT faces only (outward).
      # Returns { faces:, view_dir:, width_mm:, height_mm:, path_local: } or nil.
      def prepare_graphic_wrap_for_paint!(wrap_ent)
        return nil unless wrap_ent && wrap_ent.valid?
        make_unique_wrap_tree!(wrap_ent)
        samples = []
        tr0 = identity_transform
        gather_wrap_paint_samples!(wrap_ent, samples, 0, tr0)
        return nil if samples.empty?

        area_ny = samples.inject(0.0) { |a, s| a + s[:ny].to_f * [s[:area_mm2].to_f, 0.01].max }
        view_sign = area_ny >= 0.0 ? 1.0 : -1.0
        view_dir = Geom::Vector3d.new(0, view_sign, 0)

        # Prefer vertical faces on the outward side; loosen if sparse.
        vert = samples.select { |s| s[:nz].to_f.abs < 0.75 }
        vert = samples if vert.size < 2
        front = vert.select { |s| s[:ny].to_f * view_sign > 0.12 }
        if front.size < 2
          front = vert.select { |s| s[:ny].to_f * view_sign > 0.0 }
        end
        if front.size < 2
          max_d = vert.map { |s| s[:ny].to_f * view_sign }.max
          front = vert.select { |s| s[:ny].to_f * view_sign >= max_d - 0.1 }
        end
        front = front.sort_by { |s| -s[:area_mm2].to_f }
        # Hard cap — never the old 2500 apron dump.
        front = front.first(200) if front.size > 200
        faces = front.map { |s| s[:face] }.compact.select(&:valid?)
        return nil if faces.empty?

        # Reverse faces whose root normal points inward so material faces viewer.
        faces.each do |f|
          begin
            s = front.find { |x| x[:face] && x[:face].entityID == f.entityID }
            next unless s
            if s[:ny].to_f * view_sign < -0.05
              f.reverse!
            end
          rescue StandardError
            nil
          end
        end

        width_mm, height_mm, path_local = wrap_uv_path_from_faces(faces)
        puts "[ISOframe] prepare wrap front=#{faces.size} raw=#{samples.size} " \
             "view_sign=#{view_sign} #{width_mm.round(1)}x#{height_mm.round(1)}mm"
        {
          faces: faces,
          view_dir: view_dir,
          width_mm: width_mm,
          height_mm: height_mm,
          path_local: path_local
        }
      rescue StandardError => e
        puts "[ISOframe] prepare_graphic_wrap_for_paint! failed: #{e.message}"
        nil
      end

      def make_unique_wrap_tree!(ent, depth = 0)
        return if ent.nil? || !ent.valid? || depth > 10
        if ent.is_a?(Sketchup::ComponentInstance)
          begin
            if ent.definition && ent.definition.count_instances.to_i > 1 && ent.respond_to?(:make_unique)
              ent.make_unique
            end
          rescue StandardError
            nil
          end
          ent.definition.entities.each { |c| make_unique_wrap_tree!(c, depth + 1) }
        elsif ent.is_a?(Sketchup::Group)
          ent.entities.each { |c| make_unique_wrap_tree!(c, depth + 1) }
        end
      rescue StandardError
        nil
      end

      # Faces under the wrap paint target only (no character / posts / top).
      def gather_wrap_paint_samples!(entity_or_entities, out, depth, tr)
        return if depth > 10
        ents = entities_of(entity_or_entities)
        return if ents.nil?
        ents.each do |e|
          if e.is_a?(Sketchup::Face) && e.valid?
            n = transform_as_normal(e.normal, tr)
            out << {
              face: e,
              nx: n.x.to_f, ny: n.y.to_f, nz: n.z.to_f,
              area_mm2: face_area_mm2_local(e),
              points_root: e.outer_loop.vertices.map { |v| tr * v.position }
            }
          elsif e.is_a?(Sketchup::Group) && e.valid?
            iname = e.name.to_s
            next if iname =~ /\bsree\b|keyboard\s*top|keyboard\s*base|table\s*post|\b763\b/i
            gather_wrap_paint_samples!(e, out, depth + 1, tr * e.transformation)
          elsif e.is_a?(Sketchup::ComponentInstance) && e.valid?
            iname = e.name.to_s
            dname = def_name_of(e)
            key = "#{iname} #{dname}"
            next if key =~ /\bsree\b|keyboard\s*top|keyboard\s*base|table\s*post|\b763\b|beam|adjustable\s*foot/i
            gather_wrap_paint_samples!(e, out, depth + 1, tr * e.transformation)
          end
        end
      end

      # Straight UV path across wrap width (same helper family as wall bay path).
      def wrap_uv_path_from_faces(faces)
        pts = []
        faces.each do |f|
          next unless f.valid?
          f.outer_loop.vertices.each { |v| pts << v.position }
        rescue StandardError
          nil
        end
        raise 'No wrap verts' if pts.empty?
        xs = pts.map(&:x)
        ys = pts.map(&:y)
        zs = pts.map(&:z)
        dx = xs.max - xs.min
        dy = ys.max - ys.min
        dz = zs.max - zs.min
        y_front = (ys.min + ys.max) * 0.5
        if dx >= dy
          path = [
            Geom::Point3d.new(xs.min, y_front, 0),
            Geom::Point3d.new(xs.max, y_front, 0)
          ]
          width_mm = [dx / 1.mm, 10.0].max
        else
          path = [
            Geom::Point3d.new(xs.min, ys.min, 0),
            Geom::Point3d.new(xs.min, ys.max, 0)
          ]
          width_mm = [dy / 1.mm, 10.0].max
        end
        height_mm = [dz / 1.mm, 10.0].max
        [width_mm, height_mm, path]
      end

      # Kept for older callers / tests — delegates to prepare.
      def select_graphic_wrap_front_faces(target, tr = nil)
        prep = prepare_graphic_wrap_for_paint!(target)
        prep ? prep[:faces] : []
      end

      def graphic_wrap_view_dir(target, tr = nil)
        prep = prepare_graphic_wrap_for_paint!(target)
        prep ? prep[:view_dir] : Geom::Vector3d.new(0, 1, 0)
      rescue StandardError
        Geom::Vector3d.new(0, 1, 0)
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

      # Mark lip/apron targets with an attribute — do NOT rename (v0.1.58).
      # Renaming Groups to TableGraphicHint wiped "keyboard lip" and broke apply.
      def tag_table_graphic_groups!(defn, _stable_name = nil)
        mark_table_graphic_targets!(defn)
      end

      def mark_table_graphic_targets!(defn)
        return unless defn && defn.valid?
        walk_mark_graphics!(defn.entities, 0)
        # Prefer Graphic Keyboard Attachment (Rolable) as the artwork target.
        wrap = find_graphic_wrap_with_transform(defn.entities, 0, identity_transform)
        if wrap && wrap[0]
          mark_as_table_graphic!(wrap[0])
        elsif !find_keyboard_lip_entity(defn.entities, 0)
          geo = find_best_geometric_apron_target(defn)
          mark_as_table_graphic!(geo[0]) if geo && geo[0]
        end
      rescue StandardError
        nil
      end

      def walk_mark_graphics!(entities, depth)
        return if entities.nil? || depth > 8
        entities.each do |e|
          if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            next unless e.valid?
            iname = e.name.to_s
            dname = e.respond_to?(:definition) ? e.definition.name.to_s : ''
            # Mark graphic wrap (Rolable) and lip — never the outer wrap container.
            if graphic_wrap_paint_name?(iname, dname)
              mark_as_table_graphic!(e)
            elsif lip_name?(iname, dname) && !wrap_container?(iname, dname)
              mark_as_table_graphic!(e)
            end
            if e.is_a?(Sketchup::Group)
              walk_mark_graphics!(e.entities, depth + 1)
            else
              walk_mark_graphics!(e.definition.entities, depth + 1)
            end
          end
        end
      rescue StandardError
        nil
      end

      def mark_as_table_graphic!(ent)
        return unless ent && ent.respond_to?(:set_attribute)
        ent.set_attribute('ISOframe', 'table_graphic_target', true)
      rescue StandardError
        nil
      end

      def table_graphic_marked?(ent)
        return false unless ent && ent.respond_to?(:get_attribute)
        ent.get_attribute('ISOframe', 'table_graphic_target') == true
      rescue StandardError
        false
      end

      def dump_baked_entity_names(entities, depth, acc = [])
        return acc.join(' | ') if entities.nil? || depth > 5
        entities.each do |e|
          if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            next unless e.valid?
            iname = e.name.to_s
            dname = e.respond_to?(:definition) ? e.definition.name.to_s : ''
            acc << "#{'  ' * depth}#{e.class.name.split('::').last}:#{iname.empty? ? '(unnamed)' : iname}" \
                   "#{dname.empty? ? '' : " [#{dname}]"}"
            if e.is_a?(Sketchup::Group)
              dump_baked_entity_names(e.entities, depth + 1, acc)
            else
              dump_baked_entity_names(e.definition.entities, depth + 1, acc)
            end
          end
        end
        depth.zero? ? (acc.empty? ? '(none)' : acc.join(' | ')) : acc
      rescue StandardError => e
        "dump failed: #{e.message}"
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

      # Resolve paint target: lip → marked graphic → top → nil (caller paints faces).
      # Never renames. Never synthesizes a flat panel.
      def ensure_table_graphic_group!(defn, _stable_name = 'TableGraphicHint')
        return nil unless defn && defn.valid?
        purged = purge_synthetic_table_graphic_panels!(defn)
        puts "[ISOframe] purged synthetic table panels=#{purged}" if purged > 0
        mark_table_graphic_targets!(defn)

        lip = find_keyboard_lip_entity(defn.entities, 0)
        if lip && lip.valid?
          mark_as_table_graphic!(lip)
          puts "[ISOframe] table graphic = keyboard lip (#{lip.name})"
          return lip
        end

        marked = find_marked_table_graphic(defn.entities, 0)
        return marked if marked && marked.valid?

        top = find_keyboard_top_entity(defn.entities, 0)
        if top && top.valid?
          mark_as_table_graphic!(top)
          puts "[ISOframe] table graphic = keyboard top (#{top.name})"
          return top
        end

        puts '[ISOframe] ensure_table_graphic_group!: no named lip — apply will use face fallback'
        nil
      rescue StandardError => e
        puts "[ISOframe] ensure_table_graphic_group! failed: #{e.message}"
        nil
      end

      def find_marked_table_graphic(entities, depth)
        return nil if entities.nil? || depth > 8
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next unless e.valid?
          next if synthetic_table_graphic?(e)
          iname = e.name.to_s
          dname = e.respond_to?(:definition) ? e.definition.name.to_s : ''
          next if wrap_container?(iname, dname)
          return e if table_graphic_marked?(e) && lip_name?(iname, dname)
          nested = if e.is_a?(Sketchup::Group)
                     find_marked_table_graphic(e.entities, depth + 1)
                   else
                     find_marked_table_graphic(e.definition.entities, depth + 1)
                   end
          return nested if nested
        end
        nil
      end

      # Apron faces for Apply Table Artwork (live bake path).
      # v0.1.64: lip name often missing (Boss-Extrude…). Prefer named lip; else
      # geometric apron under the top; never-empty pool fallback. Never tabletop
      # or 37mm beams/posts/frame. Continuous UV.
      def select_keyboard_apron_faces(defn)
        return [] unless defn && defn.valid?
        samples = apron_face_samples(defn)
        if samples.empty?
          samples = geometric_apron_face_samples(defn)
          enrich_sample_z_mm!(samples)
          puts "[ISOframe] apron samples empty — geometric pool=#{samples.size}"
        end
        return [] if samples.empty?

        top_band = tabletop_z_band_mm(defn, samples)
        chosen = samples.select { |s| apron_sample_allowed?(s, top_band) }
        if chosen.empty?
          chosen = samples.select { |s| apron_sample_allowed?(s, top_band, 0.92) }
          puts "[ISOframe] apron loose-vertical count=#{chosen.size}"
        end
        if chosen.empty?
          # Last resort: non-horizontal, non-beam, outside top band — still paints.
          chosen = samples.select do |s|
            next false if s[:area_mm2].to_f < 0.5
            next false if s[:nz].to_f.abs >= 0.95
            next false if sample_beam_like?(s)
            if top_band
              zmin = s[:z_min_mm].to_f
              zmax = s[:z_max_mm].to_f
              next false if zmax >= top_band[:z_min] - 0.5 && zmin <= top_band[:z_max] + 0.5
            end
            true
          end
          puts "[ISOframe] apron last-resort count=#{chosen.size}"
        end
        if chosen.size > 8000
          chosen = chosen.sort_by { |s| -s[:area_mm2] }.first(2500)
          puts "[ISOframe] apron capped to #{chosen.size} largest faces"
        end
        faces = chosen.map { |s| s[:face] }.compact
        puts "[ISOframe] apron selected=#{faces.size} raw_samples=#{samples.size} " \
             "top_band_mm=#{top_band.inspect}"
        faces
      end

      # Keep vertical apron facets under the tabletop band; reject edge strips.
      def apron_sample_allowed?(sample, top_band, nz_max = 0.85)
        return false unless sample[:face] && sample[:face].valid?
        return false if sample[:area_mm2].to_f < 0.5
        return false if sample[:nz].to_f.abs >= nz_max
        zmin = sample[:z_min_mm].to_f
        zmax = sample[:z_max_mm].to_f
        zspan = sample[:z_span_mm].to_f
        if top_band
          return false if zmax >= top_band[:z_min] - 0.5 && zmin <= top_band[:z_max] + 0.5
          edge_max = TABLETOP_THICKNESS_MM + 2.0
          mid = (zmin + zmax) * 0.5
          if zspan <= edge_max && mid >= top_band[:z_min] - 0.5 && mid <= top_band[:z_max] + 0.5
            return false
          end
        end
        true
      end

      # Named lip → marked apron → geometric Boss-Extrude recovery.
      def apron_face_samples(defn)
        target, tr = resolve_apron_target_with_transform(defn)
        samples = []
        id = identity_transform
        if target && target.valid?
          gather_face_samples!(target, samples, 0, tr || id, 'apron')
          puts "[ISOframe] apron target raw faces=#{samples.size} " \
               "name=#{target.name} def=#{def_name_of(target)}"
        else
          puts '[ISOframe] apron: lip name NONE — geometric recovery among bake children'
          samples = geometric_apron_face_samples(defn)
          puts "[ISOframe] apron geometric faces=#{samples.size}"
        end
        enrich_sample_z_mm!(samples)
        samples
      end

      def enrich_sample_z_mm!(samples)
        samples.each do |s|
          pts = s[:points_root] || []
          zs = pts.map { |p| p.z.to_f / 1.mm }
          if zs.empty?
            s[:z_min_mm] = 0.0
            s[:z_max_mm] = 0.0
            s[:z_span_mm] = 0.0
          else
            s[:z_min_mm] = zs.min
            s[:z_max_mm] = zs.max
            s[:z_span_mm] = zs.max - zs.min
          end
        end
      end

      # Z band of keyboard top in bake-root mm. Named top, else tabletop-like bbox.
      def tabletop_z_band_mm(defn, samples)
        id = identity_transform
        top = find_keyboard_top_with_transform(defn.entities, 0, id)
        band = entity_z_band_mm(top[0], top[1]) if top && top[0]
        return band if band

        geo_top = find_tabletop_like_container(defn)
        band = entity_z_band_mm(geo_top[0], geo_top[1]) if geo_top && geo_top[0]
        return band if band

        return nil if samples.nil? || samples.empty?
        # Highest 15mm of candidate geometry — forbidden band for apron filter.
        all_zmax = samples.map { |s| s[:z_max_mm].to_f }.max
        { z_min: all_zmax - TABLETOP_THICKNESS_MM, z_max: all_zmax + 1.0 }
      rescue StandardError
        nil
      end

      def entity_z_band_mm(ent, tr)
        return nil unless ent && ent.valid?
        bb = ent.bounds
        return nil if bb.nil? || bb.empty?
        tr ||= identity_transform
        corners = [
          Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
          Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z),
          Geom::Point3d.new(bb.min.x, bb.min.y, bb.max.z),
          Geom::Point3d.new(bb.max.x, bb.max.y, bb.min.z),
          Geom::Point3d.new(bb.min.x, bb.max.y, bb.min.z),
          Geom::Point3d.new(bb.max.x, bb.min.y, bb.max.z)
        ]
        zs = corners.map { |p| (tr * p).z.to_f / 1.mm }
        return nil if zs.empty?
        { z_min: zs.min, z_max: zs.max }
      rescue StandardError
        nil
      end

      def identity_transform
        @identity_transform ||= Geom::Transformation.new
      end

      # Named lip → attribute-marked apron → geometric Boss-Extrude container.
      def resolve_apron_target_with_transform(defn)
        id = identity_transform
        hit = find_keyboard_lip_with_transform(defn.entities, 0, id)
        return hit if hit && hit[0]

        marked = find_marked_apron_target(defn.entities, 0)
        if marked && marked.valid?
          tr = find_entity_transform(defn.entities, marked, 0, id)
          return [marked, tr || id]
        end

        geo = find_best_geometric_apron_target(defn)
        if geo && geo[0]
          mark_as_table_graphic!(geo[0])
          puts "[ISOframe] apron geometric target def=#{def_name_of(geo[0])} name=#{geo[0].name}"
          return geo
        end

        [nil, nil]
      end

      # Marked apron may be a nameless Boss-Extrude (no "lip" string).
      def find_marked_apron_target(entities, depth)
        return nil if entities.nil? || depth > 8
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next unless e.valid?
          iname = e.name.to_s
          dname = def_name_of(e)
          key = "#{iname} #{dname}"
          if table_graphic_marked?(e) && !wrap_container?(iname, dname) &&
             !top_name?(iname, dname) && !blocked_apron_descend?(key)
            return e
          end
          child = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          nested = find_marked_apron_target(child, depth + 1)
          return nested if nested
        end
        nil
      end

      # Pick best bake child that looks like the curved under-table apron.
      def find_best_geometric_apron_target(defn)
        id = identity_transform
        top_band = tabletop_z_band_mm(defn, [])
        cands = []
        collect_apron_candidate_containers!(defn.entities, 0, id, '', cands)
        best = nil
        best_score = -1.0
        best_samples = nil
        cands.each do |c|
          samples = []
          gather_face_samples!(c[:ent], samples, 0, c[:tr], c[:key])
          enrich_sample_z_mm!(samples)
          score = score_apron_candidate_samples(samples, top_band)
          next if score < 0.0
          if score > best_score
            best_score = score
            best = [c[:ent], c[:tr]]
            best_samples = samples
          end
        end
        puts "[ISOframe] geometric apron score=#{best_score.round(2)} " \
             "cands=#{cands.size} faces=#{best_samples ? best_samples.size : 0}"
        best
      end

      def geometric_apron_face_samples(defn)
        target, tr = find_best_geometric_apron_target(defn)
        samples = []
        if target && target.valid?
          mark_as_table_graphic!(target)
          gather_face_samples!(target, samples, 0, tr || identity_transform, 'apron')
          return samples
        end
        # Last resort: pool non-blocked faces, then keep only those that pass
        # geometry score filters (still excludes top/beams via blocked + band).
        pool = []
        gather_face_samples!(defn, pool, 0, identity_transform, 'bake')
        enrich_sample_z_mm!(pool)
        top_band = tabletop_z_band_mm(defn, pool)
        pool.select { |s| apron_sample_allowed?(s, top_band) && !sample_beam_like?(s) }
      end

      def collect_apron_candidate_containers!(entities, depth, tr, parent_key, out)
        return if entities.nil? || depth > 8
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next unless e.valid?
          iname = e.name.to_s
          dname = def_name_of(e)
          key = "#{parent_key} #{iname} #{dname}"
          next if blocked_apron_descend?(key)
          next if wrap_container?(iname, dname)
          next if top_name?(iname, dname)
          local = tr * e.transformation
          out << { ent: e, tr: local, key: key }
          child = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          collect_apron_candidate_containers!(child, depth + 1, local, key, out)
        end
      end

      def find_tabletop_like_container(defn)
        id = identity_transform
        cands = []
        collect_apron_candidate_containers!(defn.entities, 0, id, '', cands)
        # Also allow named top path even if blocked for apron paint.
        named = find_keyboard_top_with_transform(defn.entities, 0, id)
        return named if named && named[0]

        best = nil
        best_area = 0.0
        cands.each do |c|
          dims = entity_bbox_mm(c[:ent], c[:tr])
          next unless dims
          next unless tabletop_like_dims?(dims[:dx], dims[:dy], dims[:dz])
          area = dims[:dx] * dims[:dy]
          if area > best_area
            best_area = area
            best = [c[:ent], c[:tr]]
          end
        end
        best
      end

      def entity_bbox_mm(ent, tr)
        return nil unless ent && ent.valid?
        bb = ent.bounds
        return nil if bb.nil? || bb.empty?
        tr ||= identity_transform
        corners = [
          Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
          Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z)
        ]
        pts = [
          tr * Geom::Point3d.new(bb.min.x, bb.min.y, bb.min.z),
          tr * Geom::Point3d.new(bb.max.x, bb.min.y, bb.min.z),
          tr * Geom::Point3d.new(bb.min.x, bb.max.y, bb.min.z),
          tr * Geom::Point3d.new(bb.min.x, bb.min.y, bb.max.z),
          tr * Geom::Point3d.new(bb.max.x, bb.max.y, bb.max.z)
        ]
        xs = pts.map { |p| p.x.to_f / 1.mm }
        ys = pts.map { |p| p.y.to_f / 1.mm }
        zs = pts.map { |p| p.z.to_f / 1.mm }
        {
          dx: xs.max - xs.min,
          dy: ys.max - ys.min,
          dz: zs.max - zs.min,
          z_min: zs.min,
          z_max: zs.max
        }
      rescue StandardError
        nil
      end

      # Pure-ish scorer for tests: samples with nz/area/z_*/points optional.
      def score_apron_candidate_samples(samples, top_band = nil)
        return -1.0 if samples.nil? || samples.size < APRON_MIN_FACES
        enrich_sample_z_mm!(samples) unless samples.first && samples.first.key?(:z_min_mm)
        dims = samples_bbox_mm(samples)
        return -1.0 if dims.nil?
        return -1.0 if tabletop_like_dims?(dims[:dx], dims[:dy], dims[:dz])
        return -1.0 if beam_like_dims?(dims[:dx], dims[:dy], dims[:dz])

        allowed = samples.select { |s| apron_sample_allowed?(s, top_band) }
        return -1.0 if allowed.size < APRON_MIN_FACES

        zspan = allowed.map { |s| s[:z_max_mm].to_f }.max - allowed.map { |s| s[:z_min_mm].to_f }.min
        return -1.0 if zspan < APRON_MIN_HEIGHT_MM

        horiz = samples.count { |s| s[:nz].to_f.abs >= 0.85 }
        vert_ratio = allowed.size.to_f / samples.size.to_f
        return -1.0 if horiz.to_f / samples.size > 0.55

        angle_span = samples_xy_angle_span(allowed)
        # Prefer curved (wide angle span) tall vertical clusters.
        allowed.size * (0.5 + angle_span) * (zspan / 50.0) * (0.35 + vert_ratio)
      end

      def samples_bbox_mm(samples)
        # Prefer explicit mm extents (tests / precomputed); else SketchUp points.
        if samples.any? { |s| s[:dx_mm] }
          return {
            dx: samples.map { |s| s[:dx_mm].to_f }.max,
            dy: samples.map { |s| s[:dy_mm].to_f }.max,
            dz: samples.map { |s| s[:dz_mm].to_f }.max
          }
        end
        xs = []
        ys = []
        zs = []
        samples.each do |s|
          (s[:points_root] || []).each do |p|
            xs << (p.x.to_f / 1.mm)
            ys << (p.y.to_f / 1.mm)
            zs << (p.z.to_f / 1.mm)
          end
        end
        return nil if xs.empty?
        { dx: xs.max - xs.min, dy: ys.max - ys.min, dz: zs.max - zs.min }
      rescue StandardError
        nil
      end

      def samples_xy_angle_span(samples)
        angs = samples.map { |s| Math.atan2(s[:ny].to_f, s[:nx].to_f) }
        return 0.0 if angs.empty?
        angs.max - angs.min
      rescue StandardError
        0.0
      end

      def tabletop_like_dims?(dx, dy, dz)
        dz.to_f <= TABLETOP_MAX_HEIGHT_MM &&
          dx.to_f >= TABLETOP_MIN_PLAN_MM &&
          dy.to_f >= TABLETOP_MIN_PLAN_MM
      end

      def beam_like_dims?(dx, dy, dz)
        dims = [dx.to_f, dy.to_f, dz.to_f].sort
        dims[0] <= BEAM_CROSS_MM && dims[1] <= BEAM_CROSS_MM && dims[2] >= BEAM_MIN_LENGTH_MM
      end

      def sample_beam_like?(sample)
        return false unless sample[:points_root] && sample[:points_root].size >= 2
        dims = samples_bbox_mm([sample])
        dims && beam_like_dims?(dims[:dx], dims[:dy], dims[:dz])
      rescue StandardError
        false
      end

      # Pure helpers for tests (mm extents).
      def tabletop_like_dims_mm?(dx, dy, dz)
        tabletop_like_dims?(dx, dy, dz)
      end

      def beam_like_dims_mm?(dx, dy, dz)
        beam_like_dims?(dx, dy, dz)
      end

      def find_keyboard_lip_with_transform(entities, depth, tr)
        return nil if entities.nil? || depth > 8
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next unless e.valid?
          next if synthetic_table_graphic?(e)
          iname = e.name.to_s
          dname = def_name_of(e)
          local = tr * e.transformation
          if lip_name?(iname, dname) && !wrap_container?(iname, dname) && !top_name?(iname, dname)
            return [e, local]
          end
          child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          nested = find_keyboard_lip_with_transform(child_ents, depth + 1, local)
          return nested if nested
        end
        nil
      end

      def find_keyboard_top_with_transform(entities, depth, tr)
        return nil if entities.nil? || depth > 8
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next unless e.valid?
          iname = e.name.to_s
          dname = def_name_of(e)
          local = tr * e.transformation
          if top_name?(iname, dname)
            return [e, local]
          end
          child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          nested = find_keyboard_top_with_transform(child_ents, depth + 1, local)
          return nested if nested
        end
        nil
      end

      def top_name?(iname, dname)
        n = "#{iname} #{dname}"
        !!(n =~ /keyboard\s*top/i || n =~ /table\s*attachment\s*keyboard\s*top/i)
      end

      def find_entity_transform(entities, target, depth, tr)
        return nil if entities.nil? || depth > 8
        entities.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next unless e.valid?
          local = tr * e.transformation
          return local if e == target || (e.respond_to?(:entityID) && target.respond_to?(:entityID) && e.entityID == target.entityID)
          child_ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          hit = find_entity_transform(child_ents, target, depth + 1, local)
          return hit if hit
        end
        nil
      end

      def gather_face_samples!(entity_or_entities, out, depth, tr, parent_key = 'lip')
        return if depth > 8
        ents = entities_of(entity_or_entities)
        return if ents.nil?
        ents.each do |e|
          if e.is_a?(Sketchup::Face) && e.valid?
            next if blocked_apron_descend?(parent_key)
            n = transform_as_normal(e.normal, tr)
            out << {
              face: e,
              nx: n.x.to_f, ny: n.y.to_f, nz: n.z.to_f,
              area_mm2: face_area_mm2_local(e),
              points_root: e.outer_loop.vertices.map { |v| tr * v.position }
            }
          elsif e.is_a?(Sketchup::Group) && e.valid?
            key = "#{parent_key} #{e.name}"
            next if blocked_apron_descend?(key)
            gather_face_samples!(e, out, depth + 1, tr * e.transformation, key)
          elsif e.is_a?(Sketchup::ComponentInstance) && e.valid?
            key = "#{parent_key} #{e.name} #{e.definition.name}"
            next if blocked_apron_descend?(key)
            gather_face_samples!(e, out, depth + 1, tr * e.transformation, key)
          end
        end
      end

      # Walk bake: only keep faces under a keyboard-lip path; skip top/beams/posts.
      def gather_safe_apron_samples!(entities, out, depth, tr, parent_key)
        return if entities.nil? || depth > 8
        entities.each do |e|
          if e.is_a?(Sketchup::Face) && e.valid?
            next unless parent_key =~ /keyboard\s*lip/i
            next if skip_apron_face_parent?(parent_key)
            n = transform_as_normal(e.normal, tr)
            next if n.z.abs >= 0.85
            area = face_area_mm2_local(e)
            next if area < 0.5
            out << {
              face: e,
              nx: n.x.to_f, ny: n.y.to_f, nz: n.z.to_f,
              area_mm2: area,
              points_root: e.outer_loop.vertices.map { |v| tr * v.position }
            }
          elsif e.is_a?(Sketchup::Group) && e.valid?
            key = "#{parent_key} #{e.name}"
            next if blocked_apron_descend?(key)
            gather_safe_apron_samples!(e.entities, out, depth + 1, tr * e.transformation, key)
          elsif e.is_a?(Sketchup::ComponentInstance) && e.valid?
            key = "#{parent_key} #{e.name} #{e.definition.name}"
            next if blocked_apron_descend?(key)
            gather_safe_apron_samples!(e.definition.entities, out, depth + 1, tr * e.transformation, key)
          end
        end
        out.replace(out.sort_by { |s| -s[:area_mm2] }.first(2500)) if out.size > 8000
      end

      # Do not descend into tabletop, beams, posts, feet, character, base.
      def blocked_apron_descend?(key)
        k = key.to_s
        !!(k =~ /table\s*post|\b763\b|beam\s*straight|\bbeam\b|\b37\s*mm\b|square\s*profile|t-?box|adjustable\s*foot|base\s*support|flexibeam|post\s*[ab]\b|\bsree\b|keyboard\s*top|keyboard\s*base|table\s*attachment\s*keyboard\s*top/i)
      end

      def skip_apron_face_parent?(key)
        return true if blocked_apron_descend?(key)
        k = key.to_s
        return true unless k =~ /keyboard\s*lip/i
        # Character / loose wrap faces: under wrap but not under lip.
        if k =~ /attachment\s*wrap|ISOframe Keyboard Attachment/i && k !~ /keyboard\s*lip/i
          return true
        end
        false
      end

      def entities_of(entity_or_entities)
        if entity_or_entities.is_a?(Sketchup::Group)
          entity_or_entities.entities
        elsif entity_or_entities.is_a?(Sketchup::ComponentInstance)
          entity_or_entities.definition.entities
        elsif entity_or_entities.respond_to?(:grep)
          entity_or_entities
        elsif entity_or_entities.respond_to?(:entities)
          entity_or_entities.entities
        end
      end

      def transform_as_normal(normal, tr)
        # Transform as a direction (no translation).
        p0 = tr * Geom::Point3d.new(0, 0, 0)
        p1 = tr * Geom::Point3d.new(normal.x.to_f, normal.y.to_f, normal.z.to_f)
        Geom::Vector3d.new(p1.x - p0.x, p1.y - p0.y, p1.z - p0.z)
      rescue StandardError
        normal
      end

      def def_name_of(ent)
        ent.respond_to?(:definition) ? ent.definition.name.to_s : ''
      rescue StandardError
        ''
      end

      def filter_lip_apron_faces(faces, up)
        faces.select do |f|
          next false unless f.valid?
          n_up = normal_up_component(f.normal, up)
          next false if n_up.abs >= 0.85
          face_area_mm2_local(f) >= 0.5
        end
      end

      # Axis with the most near-horizontal face area = tabletop/rim "up" in lip space.
      def detect_lip_up_axis(faces)
        scores = [0.0, 0.0, 0.0]
        faces.each do |f|
          next unless f.valid?
          n = f.normal
          area = begin
            f.area.to_f
          rescue StandardError
            0.0
          end
          ax = n.x.abs
          ay = n.y.abs
          az = n.z.abs
          if ax >= 0.85 && ax >= ay && ax >= az
            scores[0] += area
          elsif ay >= 0.85 && ay >= ax && ay >= az
            scores[1] += area
          elsif az >= 0.85
            scores[2] += area
          end
        end
        best = scores.each_with_index.max_by { |s, _i| s }
        (best && best[0] > 0.0) ? best[1] : 2
      end

      def normal_up_component(normal, up_axis)
        case up_axis
        when 0 then normal.x.to_f
        when 1 then normal.y.to_f
        else normal.z.to_f
        end
      end

      def face_area_mm2_local(face)
        face.area.to_f * 25.4 * 25.4
      rescue StandardError
        0.0
      end

      def gather_faces_deep!(entity_or_entities, out, depth)
        return if depth > 8
        ents = entities_of(entity_or_entities)
        return if ents.nil?
        ents.each do |e|
          if e.is_a?(Sketchup::Face) && e.valid?
            out << e
          elsif e.is_a?(Sketchup::Group) && e.valid?
            gather_faces_deep!(e, out, depth + 1)
          elsif e.is_a?(Sketchup::ComponentInstance) && e.valid?
            gather_faces_deep!(e, out, depth + 1)
          end
        end
      end

      def collect_apron_faces_from_definition(defn)
        select_keyboard_apron_faces(defn)
      end

      def baked_table_has_apron_faces?(defn)
        !select_keyboard_apron_faces(defn).empty?
      end

      # Pure helper for tests: bake-root samples { nx:, ny:, nz:, area_mm2: }.
      def count_apron_samples_passing(samples, _up_axis = 2)
        samples.count do |s|
          next false if s[:nz].to_f.abs >= 0.85
          s[:area_mm2].to_f >= 0.5
        end
      end

      # Old v0.1.59 filter (for regression proof in tests).
      def count_apron_samples_passing_v59(samples)
        return 0 if samples.empty?
        z_max = samples.map { |s| s[:z_max].to_f }.max
        top_cut = z_max - TABLETOP_THICKNESS_MM
        edge_max_h = TABLETOP_THICKNESS_MM + 2.0
        samples.count do |s|
          next false if s[:nz].to_f.abs >= 0.50
          span = s[:z_span_mm].to_f
          next false if span <= edge_max_h
          next false if s[:z_min].to_f >= top_cut
          s[:area_mm2].to_f >= 50.0
        end
      end

      # Simulate v0.1.61: vertical-or-all (spilled onto top/beams — kept for contrast).
      def count_apron_samples_passing_v61(samples)
        return 0 if samples.empty?
        vertical = samples.count { |s| s[:nz].to_f.abs < 0.85 && s[:area_mm2].to_f >= 0.5 }
        return vertical if vertical > 0
        samples.count { |s| s[:area_mm2].to_f >= 0.01 }
      end

      # v0.1.62: vertical under lip, exclude tabletop band + short edge strips.
      def count_apron_samples_passing_v62(samples, top_band = nil)
        return 0 if samples.empty?
        if top_band.nil?
          zmax = samples.map { |s| s[:z_max_mm].to_f }.max
          top_band = { z_min: zmax - TABLETOP_THICKNESS_MM, z_max: zmax }
        end
        samples.count do |s|
          next false if s[:nz].to_f.abs >= 0.85
          next false if s[:area_mm2].to_f < 0.5
          zmin = s[:z_min_mm].to_f
          zmax = s[:z_max_mm].to_f
          zspan = s.fetch(:z_span_mm) { zmax - zmin }.to_f
          next false if zmax >= top_band[:z_min] - 0.5 && zmin <= top_band[:z_max] + 0.5
          edge_max = TABLETOP_THICKNESS_MM + 2.0
          mid = (zmin + zmax) * 0.5
          next false if zspan <= edge_max && mid >= top_band[:z_min] - 0.5 && mid <= top_band[:z_max] + 0.5
          true
        end
      end

      # v0.1.63: geometry score > 0 for apron-like Boss-Extrude clusters.
      def count_apron_samples_passing_v63(samples, top_band = nil)
        score = score_apron_candidate_samples(samples, top_band)
        return 0 if score < 0.0
        count_apron_samples_passing_v62(samples, top_band)
      end

      def skip_container_for_apron?(key)
        blocked_apron_descend?(key) || !!(key.to_s =~ /attachment\s*wrap/i)
      end

      # Outer keyboard-attachment assembly only — NOT the Rolable/GraphicHint wrap
      # (DC name "Keyboard Attachment wrap^…" IS the paint target; v0.1.70).
      def wrap_container?(iname, dname)
        return false if graphic_wrap_definition_name?(iname) || graphic_wrap_definition_name?(dname)
        n = "#{iname} #{dname}"
        return true if n =~ /ISOframe Keyboard Attachment/i && n !~ /wrap|graphic|rolab|hint/i
        # Bare "keyboard attachment" instance/def without wrap/graphic/hint.
        bare = iname.to_s =~ /\A\s*keyboard\s*attachment\s*\z/i ||
               dname.to_s =~ /\A\s*keyboard\s*attachment\s*\z/i
        return true if bare
        false
      end

      # Walk baked table for "keyboard lip" / Table Attachment Keyboard Lip.
      def find_keyboard_lip_entity(entities, depth)
        hit = find_keyboard_lip_with_transform(entities, depth, identity_transform)
        hit ? hit[0] : nil
      end

      def find_keyboard_top_entity(entities, depth)
        return nil if entities.nil? || depth > 8
        entities.each do |e|
          if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
            next unless e.valid?
            next if synthetic_table_graphic?(e)
            iname = e.name.to_s
            dname = e.respond_to?(:definition) ? e.definition.name.to_s : ''
            if iname =~ /keyboard\s*top/i || dname =~ /keyboard\s*top/i ||
               iname =~ /table\s*attachment\s*keyboard\s*top/i ||
               dname =~ /table\s*attachment\s*keyboard\s*top/i
              return e
            end
            nested = if e.is_a?(Sketchup::Group)
                       find_keyboard_top_entity(e.entities, depth + 1)
                     else
                       find_keyboard_top_entity(e.definition.entities, depth + 1)
                     end
            return nested if nested
          end
        end
        nil
      end

      def lip_name?(iname, dname)
        n = "#{iname} #{dname}"
        !!(n =~ /keyboard\s*lip/i || n =~ /table\s*attachment\s*keyboard\s*lip/i ||
           n =~ /exhibit\s+and\s+wave\s+keyboard\s+lip/i)
      end

      # Erase v0.1.56 zero-thickness flat TableGraphicHint planes (top-level bake).
      def purge_synthetic_table_graphic_panels!(defn)
        return 0 unless defn && defn.valid?
        removed = 0
        defn.entities.to_a.each do |e|
          next unless e.valid?
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next unless synthetic_table_graphic?(e)
          begin
            e.erase!
            removed += 1
          rescue StandardError
            nil
          end
        end
        removed
      end

      def synthetic_table_graphic?(ent)
        return false unless ent && ent.valid?
        return true if marked_synthetic?(ent)
        return false unless ent.is_a?(Sketchup::Group) || ent.is_a?(Sketchup::ComponentInstance)
        iname = ent.name.to_s
        dname = ent.respond_to?(:definition) ? ent.definition.name.to_s : ''
        # Never treat real SKP lip/top/base as synthetic.
        return false if lip_name?(iname, dname)
        return false if iname =~ /keyboard\s*(top|base)/i || dname =~ /keyboard\s*(top|base)/i
        return false if dname =~ /table\s*post|beam\s*straight|adjustable\s*foot|\b763\b/i

        tagged = iname =~ /TableGraphicHint/i || dname =~ /TableGraphicHint/i
        return false unless tagged || iname =~ /\ATableGraphicHint\z/i

        # Zero-thickness / single-plane panel heuristic.
        ents = ent.is_a?(Sketchup::Group) ? ent.entities : ent.definition.entities
        faces = ents.grep(Sketchup::Face).select(&:valid?)
        nested = ents.grep(Sketchup::Group).size + ents.grep(Sketchup::ComponentInstance).size
        return false if nested > 0 && faces.size > 4

        bb = ent.bounds
        return false if bb.nil? || bb.empty?
        dx = (bb.max.x - bb.min.x).abs
        dy = (bb.max.y - bb.min.y).abs
        dz = (bb.max.z - bb.min.z).abs
        # ~0 thickness in one axis (< 2 mm) and large in the other two → synthetic plane.
        thin = [dx, dy, dz].min
        return true if thin < 2.mm && faces.size <= 2
        return true if faces.size == 1 && nested == 0
        false
      rescue StandardError
        false
      end

      def marked_synthetic?(ent)
        return false unless ent.respond_to?(:get_attribute)
        ent.get_attribute('ISOframe', KEY_SYNTHETIC_TABLE_GRAPHIC) == true ||
          ent.get_attribute('ISOframe_StandDesigner', KEY_SYNTHETIC_TABLE_GRAPHIC) == true
      rescue StandardError
        false
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
