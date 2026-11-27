# frozen_string_literal: true
# Freestanding counters (Oval first). Place anywhere on the floor — NOT attached
# to Wave starter/extension, no flexilink delete, no host-follow.
#
# v0.1.72: Oval Counter from Oval_Counter.skp (full wraparound graphic body).
# SKP is a scene with Freestanding Counter Ellipse.STL (+ floorspace / Sree);
# bake only the counter mesh into a plugin definition.

module ISOframe
  module StandDesigner
    module Counters
      module_function

      REGISTRY = {
        'oval' => {
          kind: 'oval',
          label: 'Oval Counter',
          skp_file: 'Oval_Counter.skp',
          defn_name: 'ISOframe Counter Oval v72',
          instance_name: 'ISOframe Oval Counter'
        }
      }.freeze

      SKIP_NAME_RE = /
        \bsree\b|
        floorspace|
        isoframe\s*wave|
        wave\s*(starter|extension)|
        flexibeam|
        flood\s*light|
        led\s*flood|
        \bprice\b
      /ix

      COUNTER_NAME_RE = /
        freestanding\s*counter|
        counter\s*ellipse|
        oval\s*counter|
        ellipse\.stl|
        freestanding\s*counter\s*ellipse
      /ix

      # Near-horizontal = countertop / base slab (do not paint).
      TOP_NORMAL_Z = 0.85
      # Wrap faces: mostly vertical around the body.
      WRAP_MAX_ABS_NZ = 0.45

      def label_for(kind)
        entry = REGISTRY[kind.to_s]
        entry ? entry[:label] : kind.to_s
      end

      def counter_instance?(ent)
        return false unless ent && ent.valid? && ent.is_a?(Sketchup::ComponentInstance)
        kind = Attributes.get(ent, Constants::KEY_COUNTER_KIND, '').to_s
        return true unless kind.empty?
        Attributes.get(ent, Constants::KEY_TYPE).to_s == Constants::TYPE_COUNTER
      end

      def counter_kind(ent)
        Attributes.get(ent, Constants::KEY_COUNTER_KIND, '').to_s
      end

      def selected_counter(model = Sketchup.active_model)
        return nil unless model
        model.selection.grep(Sketchup::ComponentInstance).find { |e| counter_instance?(e) }
      end

      def place_selected!(kind = 'oval')
        return unless License.require_active!
        kind = kind.to_s
        raise ArgumentError, "Unknown counter: #{kind}" unless REGISTRY.key?(kind)
        Sketchup.active_model.select_tool(Tools::PlaceCounterTool.new(kind))
        true
      end

      def definition_for!(model, kind)
        entry = REGISTRY[kind.to_s]
        raise ArgumentError, "Unknown counter: #{kind}" unless entry
        defn_name = entry[:defn_name]
        existing = model.definitions[defn_name]
        return existing if existing && !existing.image? && existing.entities.size > 0

        path = MeshImport.model_path(entry[:skp_file])
        raise "Missing bundled SKP: #{File.basename(path)}" unless File.file?(path)

        root = model.definitions.load(path)
        raise "Failed to load #{File.basename(path)}" unless root

        src = pick_counter_source(model, root)
        raise "No counter geometry in #{File.basename(path)}" unless src

        defn = existing || model.definitions.add(defn_name)
        defn.entities.clear! if defn.entities.size > 0

        # Sit the bake so its lowest Z is 0 (feet on floor plane of the def).
        bb = src.bounds
        dz = bb ? -bb.min.z : 0.0
        local = Geom::Transformation.translation(Geom::Vector3d.new(0, 0, dz))
        inst = defn.entities.add_instance(src, local)
        inst.name = entry[:instance_name] if inst.respond_to?(:name=)
        puts "[ISOframe] Counter bake kind=#{kind} src=#{src.name.inspect} " \
             "entities=#{defn.entities.size}"
        defn
      end

      def pick_counter_source(model, root)
        scored = []
        model.definitions.each do |d|
          next unless d && d.valid?
          next if d.respond_to?(:image?) && d.image?
          n = d.name.to_s
          next if n =~ SKIP_NAME_RE
          faces = 0
          begin
            faces = count_faces_deep(d.entities, 0)
          rescue StandardError
            faces = 0
          end
          next if faces < 8
          score = 0.0
          score += 80.0 if n =~ COUNTER_NAME_RE
          score += 40.0 if n =~ /\.stl/i
          score += 20.0 if n =~ /counter|ellipse|oval|freestanding/i
          score += [faces, 5000].min * 0.01
          begin
            bb = d.bounds
            unless bb.nil? || bb.empty?
              dx = (bb.max.x - bb.min.x).abs / 1.mm
              dy = (bb.max.y - bb.min.y).abs / 1.mm
              dz = (bb.max.z - bb.min.z).abs / 1.mm
              # Typical counter: low height relative to plan, not a tiny part.
              score += 25.0 if dz.between?(600.0, 1600.0) && [dx, dy].min >= 400.0
              score -= 50.0 if dz > 2200.0 # full-height wall / figure
              score -= 40.0 if dx > 4000.0 || dy > 4000.0 # floorspace slab
            end
          rescue StandardError
            nil
          end
          scored << [score, d]
        end
        scored.sort_by! { |s, _| -s }
        if scored.empty?
          return root if root && root.valid?
          return nil
        end
        best = scored.first[1]
        puts "[ISOframe] Counter source def=#{best.name.inspect} score=#{scored.first[0].round(1)}"
        best
      end

      def count_faces_deep(entities, depth)
        return 0 if entities.nil? || depth > 8
        n = entities.grep(Sketchup::Face).size
        entities.each do |e|
          if e.is_a?(Sketchup::Group)
            n += count_faces_deep(e.entities, depth + 1)
          elsif e.is_a?(Sketchup::ComponentInstance)
            n += count_faces_deep(e.definition.entities, depth + 1)
          end
        end
        n
      end

      # Vertical body faces for full wraparound paint (exclude top + near-flat base).
      def select_wrap_faces(defn)
        samples = []
        gather_face_samples!(defn.entities, samples, 0, Geom::Transformation.new)
        wrap = samples.select do |s|
          f = s[:face]
          next false unless f && f.valid?
          n = f.normal
          begin
            n = n.transform(s[:tr])
            n.normalize! if n.length > 1e-9
          rescue StandardError
            next false
          end
          next false if n.z.abs >= WRAP_MAX_ABS_NZ # not vertical enough
          area = 0.0
          begin
            area = f.area.to_f
          rescue StandardError
            area = 0.0
          end
          next false if area < 1.0e-6
          true
        end
        faces = wrap.map { |s| s[:face] }.uniq
        puts "[ISOframe] Oval wrap faces=#{faces.size} (from #{samples.size} samples)"
        faces
      end

      def gather_face_samples!(entities, out, depth, tr)
        return if entities.nil? || depth > 10
        entities.each do |e|
          if e.is_a?(Sketchup::Face)
            out << { face: e, tr: tr }
          elsif e.is_a?(Sketchup::Group)
            next if e.name.to_s =~ SKIP_NAME_RE
            gather_face_samples!(e.entities, out, depth + 1, tr * e.transformation)
          elsif e.is_a?(Sketchup::ComponentInstance)
            n = "#{e.name} #{e.definition.name}"
            next if n =~ SKIP_NAME_RE
            gather_face_samples!(e.definition.entities, out, depth + 1, tr * e.transformation)
          end
        end
      end

      # Developed oval circumference path in definition XY for continuous UV.
      def wrap_path_and_size(faces)
        pts = []
        faces.each do |f|
          next unless f && f.valid?
          f.outer_loop.vertices.each { |v| pts << v.position }
        rescue StandardError
          nil
        end
        raise 'No oval wrap vertices' if pts.empty?

        xs = pts.map { |p| p.x.to_f }
        ys = pts.map { |p| p.y.to_f }
        zs = pts.map { |p| p.z.to_f }
        cx = (xs.min + xs.max) * 0.5
        cy = (ys.min + ys.max) * 0.5
        z0 = zs.min
        z1 = zs.max
        height_mm = [(z1 - z0).abs / 1.mm, 10.0].max

        # Sample ellipse ring from plan extents (Ramanujan approx circumference).
        rx = [(xs.max - xs.min) * 0.5, 1.0.mm].max
        ry = [(ys.max - ys.min) * 0.5, 1.0.mm].max
        h = ((rx - ry) / (rx + ry))**2
        circ = Math::PI * (rx + ry) * (1.0 + (3.0 * h) / (10.0 + Math.sqrt(4.0 - 3.0 * h)))
        width_mm = [circ / 1.mm, 10.0].max

        # Path along ellipse at mid-height for paint_front_face! U mapping.
        mid_z = (z0 + z1) * 0.5
        path = []
        steps = 36
        (0..steps).each do |i|
          ang = (i.to_f / steps) * 2.0 * Math::PI
          path << Geom::Point3d.new(cx + rx * Math.cos(ang), cy + ry * Math.sin(ang), mid_z)
        end
        [width_mm, height_mm, path]
      end
    end
  end
end
