# ~*~ encoding: utf-8 ~*~
module Gollum
  class Wiki
    include Pagination

    class << self
      # Sets the page class used by all instances of this Wiki.
      attr_writer :page_class

      # Sets the file class used by all instances of this Wiki.
      attr_writer :file_class

      # Sets the markup class used by all instances of this Wiki.
      attr_writer :markup_classes

      # Sets the default ref for the wiki.
      attr_writer :default_ref

      # Sets the default name for commits.
      attr_writer :default_committer_name

      # Sets the default email for commits.
      attr_writer :default_committer_email

      # Array of chars to substitute whitespace for when trying to locate file in git repo.
      attr_writer :default_ws_subs

      # Sets sanitization options. Set to false to deactivate
      # sanitization altogether.
      attr_writer :sanitization

      # Sets sanitization options. Set to false to deactivate
      # sanitization altogether.
      attr_writer :history_sanitization

      # Hash for setting different default wiki options
      # These defaults can be overridden by options passed directly to initialize()
      attr_writer :default_options

      # Gets the page class used by all instances of this Wiki.
      # Default: Gollum::Page.
      def page_class
        @page_class ||
            if superclass.respond_to?(:page_class)
              superclass.page_class
            else
              ::Gollum::Page
            end
      end

      # Gets the file class used by all instances of this Wiki.
      # Default: Gollum::File.
      def file_class
        @file_class ||
            if superclass.respond_to?(:file_class)
              superclass.file_class
            else
              ::Gollum::File
            end
      end

      # Gets the markup class used by all instances of this Wiki.
      # Default: Gollum::Markup
      def markup_classes
        @markup_classes ||=
            if superclass.respond_to?(:markup_classes)
              superclass.markup_classes
            else
              Hash.new(::Gollum::Markup)
            end
      end

      # Gets the default markup class used by all instances of this Wiki.
      # Kept for backwards compatibility until Gollum v2.x
      def markup_class(language=:default)
        markup_classes[language]
      end

      # Sets the default markup class used by all instances of this Wiki.
      # Kept for backwards compatibility until Gollum v2.x
      def markup_class=(default)
        @markup_classes = Hash.new(default).update(markup_classes)
        default
      end

      alias_method :default_markup_class, :markup_class
      alias_method :default_markup_class=, :markup_class=

      # Gets the default sanitization options for current pages used by
      # instances of this Wiki.
      def sanitization
        if @sanitization.nil?
          @sanitization = Sanitization.new
        end
        @sanitization
      end

      # Gets the default sanitization options for older page revisions used by
      # instances of this Wiki.
      def history_sanitization
        if @history_sanitization.nil?
          @history_sanitization = sanitization ?
              sanitization.history_sanitization :
              false
        end
        @history_sanitization
      end

      def default_ref
        @default_ref || 'master'
      end

      def default_committer_name
        @default_committer_name || 'Anonymous'
      end

      def default_committer_email
        @default_committer_email || 'anon@anon.com'
      end

      def default_ws_subs
        @default_ws_subs || ['_', '-']
      end

      def default_options
        @default_options || {}
      end
    end

    # The String base path to prefix to internal links. For example, when set
    # to "/wiki", the page "Hobbit" will be linked as "/wiki/Hobbit". Defaults
    # to "/".
    attr_reader :base_path

    # Gets the sanitization options for current pages used by this Wiki.
    attr_reader :sanitization

    # Gets the sanitization options for older page revisions used by this Wiki.
    attr_reader :history_sanitization

    # Gets the String ref in which all page files reside.
    attr_reader :ref

    # Gets the String directory in which all page files reside.
    attr_reader :page_file_dir

    # Gets the Array of chars to sub for ws in filenames.
    attr_reader :ws_subs

    # Gets the boolean live preview value.
    attr_reader :live_preview

    # Injects custom css from custom.css in root repo.
    # Defaults to false
    attr_reader :css

    # Sets page title to value of first h1
    # Defaults to false
    attr_reader :h1_title

    # Gets the custom index page for / and subdirs (e.g. foo/)
    attr_reader :index_page

    # Gets side on which the sidebar should be shown
    attr_reader :bar_side

    # An array of symbols which refer to classes under Gollum::Filter,
    # each of which is an element in the "filtering chain".  See
    # the documentation for Gollum::Filter for more on how this chain
    # works, and what filter classes need to implement.
    attr_reader :filter_chain

    # Public: Initialize a new Gollum Repo.
    #
    # path    - The String path to the Git repository that holds the Gollum
    #           site.
    # options - Optional Hash:
    #           :universal_toc - Table of contents on all pages.  Default: false
    #           :live_preview  - Livepreview editing for markdown files. Default: true
    #           :base_path     - String base path for all Wiki links.
    #                            Default: "/"
    #           :page_class    - The page Class. Default: Gollum::Page
    #           :file_class    - The file Class. Default: Gollum::File
    #           :markup_classes - A hash containing the markup Classes for each
    #                             document type. Default: { Gollum::Markup }
    #           :sanitization  - An instance of Sanitization.
    #           :page_file_dir - String the directory in which all page files reside
    #           :ref - String the repository ref to retrieve pages from
    #           :ws_subs       - Array of chars to sub for ws in filenames.
    #           :mathjax       - Set to false to disable mathjax.
    #           :user_icons    - Enable user icons on the history page. [gravatar, identicon, none].
    #                            Default: none
    #           :show_all      - Show all files in file view, not just valid pages.
    #                            Default: false
    #           :collapse_tree - Start with collapsed file view. Default: false
    #           :css           - Include the custom.css file from the repo.
    #           :emoji         - Parse and interpret emoji tags (e.g. :heart:).
    #           :h1_title      - Concatenate all h1's on a page to form the
    #                            page title.
    #           :index_page    - The default page to retrieve or create if the
    #                            a directory is accessed.
    #           :bar_side      - Where the sidebar should be displayed, may be:
    #                             - :left
    #                             - :right
    #           :allow_uploads - Set to true to allow file uploads.
    #           :per_page_uploads - Whether uploads should be stored in a central
    #                            'uploads' directory, or in a directory named for
    #                            the page they were uploaded to.
    #           :filter_chain  - Override the default filter chain with your own.
    #
    # Returns a fresh Gollum::Repo.
    def initialize(path, options = {})
      options = self.class.default_options.merge(options)
      if path.is_a?(GitAccess)
        options[:access] = path
        path             = path.path
      end

      # Use .fetch instead of ||
      #
      # o = { :a => false }
      # o[:a] || true # => true
      # o.fetch :a, true # => false

      @path                 = path
      @repo_is_bare         = options.fetch :repo_is_bare, nil
      @page_file_dir        = options.fetch :page_file_dir, nil
      @access               = options.fetch :access, GitAccess.new(path, @page_file_dir, @repo_is_bare)
      @base_path            = options.fetch :base_path, "/"
      @page_class           = options.fetch :page_class, self.class.page_class
      @file_class           = options.fetch :file_class, self.class.file_class
      @markup_classes       = options.fetch :markup_classes, self.class.markup_classes
      @repo                 = @access.repo
      @ref                  = options.fetch :ref, self.class.default_ref
      @sanitization         = options.fetch :sanitization, self.class.sanitization
      @ws_subs              = options.fetch :ws_subs, self.class.default_ws_subs
      @history_sanitization = options.fetch :history_sanitization, self.class.history_sanitization
      @live_preview         = options.fetch :live_preview, true
      @universal_toc        = options.fetch :universal_toc, false
      @mathjax              = options.fetch :mathjax, false
      @show_all             = options.fetch :show_all, false
      @collapse_tree        = options.fetch :collapse_tree, false
      @css                  = options.fetch :css, false
      @emoji                = options.fetch :emoji, false
      @h1_title             = options.fetch :h1_title, false
      @index_page           = options.fetch :index_page, 'Home'
      @bar_side             = options.fetch :sidebar, :right
      @user_icons           = ['gravatar', 'identicon'].include?(options[:user_icons]) ?
          options[:user_icons] : 'none'
      @allow_uploads        = options.fetch :allow_uploads, false
      @per_page_uploads     = options.fetch :per_page_uploads, false
      @filter_chain         = options.fetch :filter_chain,
                                            [:Metadata, :PlainText, :TOC, :RemoteCode, :Code, :Macro, :Emoji, :Sanitize, :WSD, :PlantUML, :Tags, :Render]
      @filter_chain.delete(:Emoji) unless options.fetch :emoji, false
    end

    # Public: check whether the wiki's git repo exists on the filesystem.
    #
    # Returns true if the repo exists, and false if it does not.
    def exist?
      @access.exist?
    end

    # Public: Get the formatted page for a given page name, version, and dir.
    #
    # name    - The human or canonical String page name of the wiki page.
    # version - The String version ID to find (default: @ref).
    # dir     - The directory String relative to the repo.
    #
    # Returns a Gollum::Page or nil if no matching page was found.
    def page(name, version = @ref, dir = nil, exact = false)
      version = @ref if version.nil?
      @page_class.new(self).find(name, version, dir, exact)
    end

    # Public: Convenience method instead of calling page(name, nil, dir).
    #
    # name    - The human or canonical String page name of the wiki page.
    # version - The String version ID to find (default: @ref).
    # dir     - The directory String relative to the repo.
    #
    # Returns a Gollum::Page or nil if no matching page was found.
    def paged(name, dir = nil, exact = false, version = @ref)
      page(name, version, dir, exact)
    end

    # Public: Get the static file for a given name.
    #
    # name    - The full String pathname to the file.
    # version - The String version ID to find (default: @ref).
    # try_on_disk - If true, try to return just a reference to a file
    #               that exists on the disk.
    #
    # Returns a Gollum::File or nil if no matching file was found. Note
    # that if you specify try_on_disk=true, you may or may not get a file
    # for which on_disk? is actually true.
    def file(name, version = @ref, try_on_disk = false)
      @file_class.new(self).find(name, version, try_on_disk)
    end

    # Public: Create an in-memory Page with the given data and format. This
    # is useful for previewing what content will look like before committing
    # it to the repository.
    #
    # name   - The String name of the page.
    # format - The Symbol format of the page.
    # data   - The new String contents of the page.
    #
    # Returns the in-memory Gollum::Page.
    def preview_page(name, data, format)
      page = @page_class.new(self)
      ext  = @page_class.format_to_ext(format.to_sym)
      name = @page_class.cname(name) + '.' + ext
      blob = OpenStruct.new(:name => name, :data => data, :is_symlink => false)
      page.populate(blob)
      page.version = @access.commit(@ref)
      page
    end

    # Public: Write a new version of a page to the Gollum repo root.
    #
    # name   - The String name of the page.
    # format - The Symbol format of the page.
    # data   - The new String contents of the page.
    # commit - The commit Hash details:
    #          :message   - The String commit message.
    #          :name      - The String author full name.
    #          :email     - The String email address.
    #          :parent    - Optional Gollum::Git::Commit parent to this update.
    #          :tree      - Optional String SHA of the tree to create the
    #                       index from.
    #          :committer - Optional Gollum::Committer instance.  If provided,
    #                       assume that this operation is part of batch of
    #                       updates and the commit happens later.
    # dir    - The String subdirectory of the Gollum::Page without any
    #          prefix or suffix slashes (e.g. "foo/bar").
    # Returns the String SHA1 of the newly written version, or the
    # Gollum::Committer instance if this is part of a batch update.
    def write_page(name, format, data, commit = {}, dir = '')
      # spaces must be dashes
      sanitized_name = name.gsub(' ', '-')
      sanitized_dir  = dir.gsub(' ', '-')
      sanitized_dir  = ::File.join([@page_file_dir, sanitized_dir].compact)

      multi_commit = !!commit[:committer]
      committer    = multi_commit ? commit[:committer] : Committer.new(self, commit)

      filename = Gollum::Page.cname(sanitized_name)

      committer.add_to_index(sanitized_dir, filename, format, data)

      committer.after_commit do |index, _sha|
        @access.refresh
        index.update_working_dir(sanitized_dir, filename, format)
      end

      multi_commit ? committer : committer.commit
    end

    # Public: Rename an existing page without altering content.
    #
    # page   - The Gollum::Page to update.
    # rename - The String extension-less full path of the page (leading '/' is ignored).
    # commit - The commit Hash details:
    #          :message   - The String commit message.
    #          :name      - The String author full name.
    #          :email     - The String email address.
    #          :parent    - Optional Gollum::Git::Commit parent to this update.
    #          :tree      - Optional String SHA of the tree to create the
    #                       index from.
    #          :committer - Optional Gollum::Committer instance.  If provided,
    #                       assume that this operation is part of batch of
    #                       updates and the commit happens later.
    #
    # Returns the String SHA1 of the newly written version, or the
    # Gollum::Committer instance if this is part of a batch update.
    # Returns false if the operation is a NOOP.
    def rename_page(page, rename, commit = {})
      return false if page.nil?
      return false if rename.nil? or rename.empty?

      (target_dir, target_name) = ::File.split(rename)
      (source_dir, source_name) = ::File.split(page.path)
      source_name               = page.filename_stripped

      # File.split gives us relative paths with ".", commiter.add_to_index doesn't like that.
      target_dir                = '' if target_dir == '.'
      source_dir                = '' if source_dir == '.'
      target_dir                = target_dir.gsub(/^\//, '')

      # if the rename is a NOOP, abort
      if source_dir == target_dir and source_name == target_name
        return false
      end

      multi_commit = !!commit[:committer]
      committer    = multi_commit ? commit[:committer] : Committer.new(self, commit)

      committer.delete(page.path)
      committer.add_to_index(target_dir, target_name, page.format, page.raw_data)

      committer.after_commit do |index, _sha|
        @access.refresh
        index.update_working_dir(source_dir, source_name, page.format)
        index.update_working_dir(target_dir, target_name, page.format)
      end

      multi_commit ? committer : committer.commit
    end

    # Public: Update an existing page with new content. The location of the
    # page inside the repository will not change. If the given format is
    # different than the current format of the page, the filename will be
    # changed to reflect the new format.
    #
    # page   - The Gollum::Page to update.
    # name   - The String extension-less name of the page.
    # format - The Symbol format of the page.
    # data   - The new String contents of the page.
    # commit - The commit Hash details:
    #          :message   - The String commit message.
    #          :name      - The String author full name.
    #          :email     - The String email address.
    #          :parent    - Optional Gollum::Git::Commit parent to this update.
    #          :tree      - Optional String SHA of the tree to create the
    #                       index from.
    #          :committer - Optional Gollum::Committer instance.  If provided,
    #                       assume that this operation is part of batch of
    #                       updates and the commit happens later.
    #
    # Returns the String SHA1 of the newly written version, or the
    # Gollum::Committer instance if this is part of a batch update.
    def update_page(page, name, format, data, commit = {})
      name     ||= page.name
      format   ||= page.format
      dir      = ::File.dirname(page.path)
      dir      = '' if dir == '.'
      filename = (rename = page.name != name) ?
          Gollum::Page.cname(name) : page.filename_stripped

      multi_commit = !!commit[:committer]
      committer    = multi_commit ? commit[:committer] : Committer.new(self, commit)

      if !rename && page.format == format
        committer.add(page.path, normalize(data))
      else
        committer.delete(page.path)
        committer.add_to_index(dir, filename, format, data)
      end

      committer.after_commit do |index, _sha|
        @access.refresh
        index.update_working_dir(dir, page.filename_stripped, page.format)
        index.update_working_dir(dir, filename, format)
      end

      multi_commit ? committer : committer.commit
    end

    # Public: Delete a page.
    #
    # page   - The Gollum::Page to delete.
    # commit - The commit Hash details:
    #          :message   - The String commit message.
    #          :name      - The String author full name.
    #          :email     - The String email address.
    #          :parent    - Optional Gollum::Git::Commit parent to this update.
    #          :tree      - Optional String SHA of the tree to create the
    #                       index from.
    #          :committer - Optional Gollum::Committer instance.  If provided,
    #                       assume that this operation is part of batch of
    #                       updates and the commit happens later.
    #
    # Returns the String SHA1 of the newly written version, or the
    # Gollum::Committer instance if this is part of a batch update.
    def delete_page(page, commit)

      multi_commit = !!commit[:committer]
      committer    = multi_commit ? commit[:committer] : Committer.new(self, commit)

      committer.delete(page.path)

      committer.after_commit do |index, _sha|
        dir = ::File.dirname(page.path)
        dir = '' if dir == '.'

        @access.refresh
        index.update_working_dir(dir, page.filename_stripped, page.format)
      end

      multi_commit ? committer : committer.commit
    end

    # Public: Delete a file.
    #
    # path   - The path to the file to delete
    # commit - The commit Hash details:
    #          :message   - The String commit message.
    #          :name      - The String author full name.
    #          :email     - The String email address.
    #          :parent    - Optional Gollum::Git::Commit parent to this update.
    #          :tree      - Optional String SHA of the tree to create the
    #                       index from.
    #          :committer - Optional Gollum::Committer instance.  If provided,
    #                       assume that this operation is part of batch of
    #                       updates and the commit happens later.
    #
    # Returns the String SHA1 of the newly written version, or the
    # Gollum::Committer instance if this is part of a batch update.
    def delete_file(path, commit)
      dir      = ::File.dirname(path)
      ext      = ::File.extname(path)
      format   = ext.split('.').last || 'txt'
      filename = ::File.basename(path, ext)

      multi_commit = !!commit[:committer]
      committer    = multi_commit ? commit[:committer] : Committer.new(self, commit)

      committer.delete(path)

      committer.after_commit do |index, _sha|
        dir = '' if dir == '.'

        @access.refresh
        index.update_working_dir(dir, filename, format)
      end

      multi_commit ? committer : committer.commit
    end

    # Public: Applies a reverse diff for a given page.  If only 1 SHA is given,
    # the reverse diff will be taken from its parent (^SHA...SHA).  If two SHAs
    # are given, the reverse diff is taken from SHA1...SHA2.
    #
    # page   - The Gollum::Page to delete.
    # sha1   - String SHA1 of the earlier parent if two SHAs are given,
    #          or the child.
    # sha2   - Optional String SHA1 of the child.
    # commit - The commit Hash details:
    #          :message - The String commit message.
    #          :name    - The String author full name.
    #          :email   - The String email address.
    #          :parent  - Optional Gollum::Git::Commit parent to this update.
    #
    # Returns a String SHA1 of the new commit, or nil if the reverse diff does
    # not apply.
    def revert_page(page, sha1, sha2 = nil, commit = {})
      if sha2.is_a?(Hash)
        commit = sha2
        sha2   = nil
      end

      patch     = full_reverse_diff_for(page, sha1, sha2)
      committer = Committer.new(self, commit)
      parent    = committer.parents[0]
      committer.options[:tree] = @repo.git.apply_patch(parent.sha, patch)
      return false unless committer.options[:tree]
      committer.after_commit do |index, _sha|
        @access.refresh

        files = []
        if page
          files << [page.path, page.filename_stripped, page.format]
        else
          # Grit::Diff can't parse reverse diffs.... yet
          patch.each_line do |line|
            if line =~ %r(^diff --git b/.+? a/(.+)$)
              path = Regexp.last_match[1]
              ext  = ::File.extname(path)
              name = ::File.basename(path, ext)
              if (format = ::Gollum::Page.format_for(ext))
                files << [path, name, format]
              end
            end
          end
        end

        files.each do |(path, name, format)|
          dir = ::File.dirname(path)
          dir = '' if dir == '.'
          index.update_working_dir(dir, name, format)
        end
      end

      committer.commit
    end

    # Public: Applies a reverse diff to the repo.  If only 1 SHA is given,
    # the reverse diff will be taken from its parent (^SHA...SHA).  If two SHAs
    # are given, the reverse diff is taken from SHA1...SHA2.
    #
    # sha1   - String SHA1 of the earlier parent if two SHAs are given,
    #          or the child.
    # sha2   - Optional String SHA1 of the child.
    # commit - The commit Hash details:
    #          :message - The String commit message.
    #          :name    - The String author full name.
    #          :email   - The String email address.
    #
    # Returns a String SHA1 of the new commit, or nil if the reverse diff does
    # not apply.
    def revert_commit(sha1, sha2 = nil, commit = {})
      revert_page(nil, sha1, sha2, commit)
    end

    # Public: Lists all pages for this wiki.
    #
    # treeish - The String commit ID or ref to find  (default:  @ref)
    #
    # Returns an Array of Gollum::Page instances.
    def pages(treeish = nil)
      tree_list(treeish || @ref)
    end

    # Public: Lists all non-page files for this wiki.
    #
    # treeish - The String commit ID or ref to find  (default:  @ref)
    #
    # Returns an Array of Gollum::File instances.
    def files(treeish = nil)
      file_list(treeish || @ref)
    end

    # Public: Returns the number of pages accessible from a commit
    #
    # ref - A String ref that is either a commit SHA or references one.
    #
    # Returns a Fixnum
    def size(ref = nil)
      tree_map_for(ref || @ref).inject(0) do |num, entry|
        num + (@page_class.valid_page_name?(entry.name) ? 1 : 0)
      end
    rescue Gollum::Git::NoSuchShaFound
      0
    end

    # Public: Search all pages for this wiki.
    #
    # query - The string to search for
    #
    # Returns an Array with Objects of page name and count of matches
    def search(query)
      options = {:path => page_file_dir, :ref => ref}
      results = {}
      @repo.git.grep(query, options).each do |hit|
        name = hit[:name]
        count = hit[:count]
        # Remove ext only from known extensions.
        # test.pdf => test.pdf, test.md => test
        file_name = Page::valid_page_name?(name) ? name.chomp(::File.extname(name)) : name
        results[file_name] = count.to_i
      end

      # Use git ls-files '*query*' to search for file names. Grep only searches file content.
      # Spaces are converted to dashes when saving pages to disk.
      @repo.git.ls_files(query.gsub(' ','-'), options).each do |path|
        # Remove ext only from known extensions.
        file_name          = Page::valid_page_name?(path) ? path.chomp(::File.extname(path)) : path
        # If there's not already a result for file_name then
        # the value is nil and nil.to_i is 0.
        results[file_name] = results[file_name].to_i + 1;
      end

      results.map do |key, val|
        { :count => val, :name => key }
      end
    end

    # Public: All of the versions that have touched the Page.
    #
    # options - The options Hash:
    #           :page     - The Integer page number (default: 1).
    #           :per_page - The Integer max count of items to return.
    #
    # Returns an Array of Gollum::Git::Commit.
    def log(options = {})
      @repo.log(@ref, nil, log_pagination_options(options))
    end

    # Returns the latest changes in the wiki (globally)
    #
    # options - The options Hash:
    #           :max_count  - The Integer number of items to return.
    #
    # Returns an Array of Gollum::Git::Commit.
    def latest_changes(options={})
      options[:max_count] = 10 unless options[:max_count]
      @repo.log(@ref, nil, options)
    end

    # Public: Refreshes just the cached Git reference data.  This should
    # be called after every Gollum update.
    #
    # Returns nothing.
    def clear_cache
      @access.refresh
    end

    # Public: Creates a Sanitize instance using the Wiki's sanitization
    # options.
    #
    # Returns a Sanitize instance.
    def sanitizer
      if (options = sanitization)
        @sanitizer ||= options.to_sanitize
      end
    end

    # Public: Creates a Sanitize instance using the Wiki's history sanitization
    # options.
    #
    # Returns a Sanitize instance.
    def history_sanitizer
      if (options = history_sanitization)
        @history_sanitizer ||= options.to_sanitize
      end
    end

    # Public: Add an additional link to the filter chain.
    #
    # name - A symbol which represents the name of a class under the
    #        Gollum::Render namespace to insert into the chain.
    #
    # loc  - A "location specifier" -- that is, where to put the new
    #        filter in the chain.  This can be one of `:first`, `:last`,
    #        `:before => :SomeElement`, or `:after => :SomeElement`, where
    #        `:SomeElement` (if specified) is a symbol already in the
    #        filter chain.  A `:before` or `:after` which references a
    #        filter that doesn't exist will cause `ArgumentError` to be
    #        raised.
    #
    # Returns nothing.
    def add_filter(name, loc)
      unless name.is_a? Symbol
        raise ArgumentError,
              "Invalid filter name #{name.inspect} (must be a symbol)"
      end

      case loc
        when :first
          @filter_chain.unshift(name)
        when :last
          @filter_chain.push(name)
        when Hash
          if loc.length != 1
            raise ArgumentError,
                  "Invalid location specifier"
          end
          if ([:before, :after] && loc.keys).empty?
            raise ArgumentError,
                  "Invalid location specifier"
          end

          next_to  = loc.values.first
          relative = loc.keys.first

          i = @filter_chain.index(next_to)
          if i.nil?
            raise ArgumentError,
                  "Unknown filter #{next_to.inspect}"
          end

          i += 1 if relative == :after
          @filter_chain.insert(i, name)
        else
          raise ArgumentError,
                "Invalid location specifier"
      end
    end

    # Remove the named filter from the filter chain.
    #
    # Returns nothing.  Raises `ArgumentError` if the named filter doesn't
    # exist in the chain.
    def remove_filter(name)
      unless name.is_a? Symbol
        raise ArgumentError,
              "Invalid filter name #{name.inspect} (must be a symbol)"
      end

      unless @filter_chain.delete(name)
        raise ArgumentError,
              "#{name.inspect} not found in filter chain"
      end
    end

    #########################################################################
    #
    # Internal Methods
    #
    #########################################################################

    # The Gollum::Git::Repo associated with the wiki.
    #
    # Returns the Gollum::Git::Repo.
    attr_reader :repo

    # The String path to the Git repository that holds the Gollum site.
    #
    # Returns the String path.
    attr_reader :path

    # Gets the page class used by all instances of this Wiki.
    attr_reader :page_class

    # Gets the file class used by all instances of this Wiki.
    attr_reader :file_class

    # Gets the markup class used by all instances of this Wiki.
    attr_reader :markup_classes

    # Toggles display of universal table of contents
    attr_reader :universal_toc

    # Toggles mathjax.
    attr_reader :mathjax

    # Toggles user icons. Default: 'none'
    attr_reader :user_icons

    # Toggles showing all files in files view. Default is false.
    # When false, only valid pages in the git repo are displayed.
    attr_reader :show_all

    # Start with collapsed file view. Default: false
    attr_reader :collapse_tree

    # Toggles file upload functionality.
    attr_reader :allow_uploads

    # Toggles whether uploaded files go into 'uploads', or a directory
    # named after the page they were uploaded to.
    attr_reader :per_page_uploads

    # Normalize the data.
    #
    # data - The String data to be normalized.
    #
    # Returns the normalized data String.
    def normalize(data)
      data.gsub(/\r/, '')
    end

    # Assemble a Page's filename from its name and format.
    #
    # name   - The String name of the page (should be pre-canonicalized).
    # format - The Symbol format of the page.
    #
    # Returns the String filename.
    def page_file_name(name, format)
      name + '.' + @page_class.format_to_ext(format)
    end

    # Fill an array with a list of pages.
    #
    # ref - A String ref that is either a commit SHA or references one.
    #
    # Returns a flat Array of Gollum::Page instances.
    def tree_list(ref)
      if (sha = @access.ref_to_sha(ref))
        commit = @access.commit(sha)
        tree_map_for(sha).inject([]) do |list, entry|
          next list unless @page_class.valid_page_name?(entry.name)
          list << entry.page(self, commit)
        end
      else
        []
      end
    end

    # Fill an array with a list of files.
    #
    # ref - A String ref that is either a commit SHA or references one.
    #
    # Returns a flat Array of Gollum::File instances.
    def file_list(ref)
      if (sha = @access.ref_to_sha(ref))
        commit = @access.commit(sha)
        tree_map_for(sha).inject([]) do |list, entry|
          next list if entry.name.start_with?('_')
          next list if @page_class.valid_page_name?(entry.name)
          list << entry.file(self, commit)
        end
      else
        []
      end
    end

    # Creates a reverse diff for the given SHAs on the given Gollum::Page.
    #
    # page   - The Gollum::Page to scope the patch to, or a String Path.
    # sha1   - String SHA1 of the earlier parent if two SHAs are given,
    #          or the child.
    # sha2   - Optional String SHA1 of the child.
    #
    # Returns a String of the reverse Diff to apply.
    def full_reverse_diff_for(page, sha1, sha2 = nil)
      sha1, sha2 = "#{sha1}^", sha1 if sha2.nil?
      if page
        path = (page.respond_to?(:path) ? page.path : page.to_s)
        return repo.diff(sha2, sha1, path).first.diff
      end
      repo.diff(sha2, sha1).map { |d| d.diff }.join("\n")
    end

    # Creates a reverse diff for the given SHAs.
    #
    # sha1   - String SHA1 of the earlier parent if two SHAs are given,
    #          or the child.
    # sha2   - Optional String SHA1 of the child.
    #
    # Returns a String of the reverse Diff to apply.
    def full_reverse_diff(sha1, sha2 = nil)
      full_reverse_diff_for(nil, sha1, sha2)
    end

    # Gets the default name for commits.
    #
    # Returns the String name.
    def default_committer_name
      @default_committer_name ||= \
        @repo.config['user.name'] || self.class.default_committer_name
    end

    # Gets the default email for commits.
    #
    # Returns the String email address.
    def default_committer_email
      email = @repo.config['user.email']
      email = email.delete('<>') if email
      @default_committer_email ||= email || self.class.default_committer_email
    end

    # Gets the commit object for the given ref or sha.
    #
    # ref - A string ref or SHA pointing to a valid commit.
    #
    # Returns a Gollum::Git::Commit instance.
    def commit_for(ref)
      @access.commit(ref)
    rescue Gollum::Git::NoSuchShaFound
    end

    # Finds a full listing of files and their blob SHA for a given ref.  Each
    # listing is cached based on its actual commit SHA.
    #
    # ref - A String ref that is either a commit SHA or references one.
    # ignore_page_file_dir - Boolean, if true, searches all files within the git repo, regardless of dir/subdir
    #
    # Returns an Array of BlobEntry instances.
    def tree_map_for(ref, ignore_page_file_dir=false)
      if ignore_page_file_dir && !@page_file_dir.nil?
        @root_access ||= GitAccess.new(path, nil, @repo_is_bare)
        @root_access.tree(ref)
      else
        @access.tree(ref)
      end
    rescue Gollum::Git::NoSuchShaFound
      []
    end

    def inspect
      %(#<#{self.class.name}:#{object_id} #{@repo.path}>)
    end
  end
end
