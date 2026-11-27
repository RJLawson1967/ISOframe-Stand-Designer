# frozen_string_literal: true
# Lightweight OBJ → ComponentDefinition builder (no SketchUp importer needed).
# Bundled meshes live under isoframe_stand_designer/models/ (mm units).

module ISOframe
  module StandDesigner
    module MeshImport
      module_function

      # Resolve at call time from this file's directory (release zip layout:
      # isoframe_stand_designer/mesh_import.rb + isoframe_stand_designer/models/).
      def models_dir
        File.expand_path(File.join(File.dirname(File.expand_path(__FILE__)), 'models'))
      end

      MODELS_DIR = File.join(File.dirname(__FILE__), 'models').freeze

      def model_path(filename)
        File.join(models_dir, filename.to_s)
      end

      # Load (or reuse) a definition named `defn_name` from a bundled OBJ.
      # OBJ vertices are millimetres; converted with .mm for SketchUp inches.
      def definition_from_obj!(model, defn_name, filename, color: nil)
        existing = model.definitions[defn_name]
        return existing if existing && !existing.image? && existing.entities.size > 0

        path = model_path(filename)
        raise "Missing bundled mesh: #{filename}" unless File.file?(path)

        defn = existing || model.definitions.add(defn_name)
        defn.entities.clear! if defn.entities.size > 0
        build_obj_into!(defn.entities, path, color: color)
        defn
      end

      def build_obj_into!(ents, path, color: nil)
        verts = []
        File.foreach(path) do |line|
          line = line.strip
          next if line.empty? || line.start_with?('#')
          parts = line.split
          case parts[0]
          when 'v'
            verts << Geom::Point3d.new(
              parts[1].to_f.mm,
              parts[2].to_f.mm,
              parts[3].to_f.mm
            )
          when 'f'
            idxs = parts[1..-1].map { |tok| tok.split('/').first.to_i }
            next if idxs.size < 3
            pts = idxs.map { |i| verts[i - 1] }
            next if pts.any?(&:nil?)
            # Fan triangulated faces (OBJ may be n-gons; ours are tris).
            (1...pts.size - 1).each do |k|
              face = ents.add_face(pts[0], pts[k], pts[k + 1])
              next unless face && color
              face.material = color
              face.back_material = color
            end
          end
        end
        ents
      end
    end
  end
end
