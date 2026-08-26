# require "sdoc"
require "rdoc/task"
require_relative "../lib/net/imap"
require 'rdoc/rdoc' unless defined?(RDoc::Markup::ToHtml)

module RDoc::Generator
  module NetIMAP

    module FixPrismParserAttrVisitor

      # Replaces the version in rdoc 8.0 with rdoc 7.2 behavior
      def _visit_call_attr_reader_writer_accessor(call_node, rw)
        return if @scanner.in_proc_block
        names = initial_symbol_arguments(call_node) or return
        @scanner.add_attributes(names.map(&:to_s), rw, call_node.location.start_line)
      end

      # Unlike #symbol_arguments, which is strict about _all_ arguments being
      # symbol literals, this returns initial symbol args and ignores the rest.
      def initial_symbol_arguments(call_node)
        arguments_node = call_node.arguments or return
        symbol_args = arguments_node.arguments
          .slice_before {|arg| !arg.is_a?(Prism::SymbolNode) }
          .first
        symbol_args.map {|arg| arg.value.to_sym } if symbol_args.any?
      end

    end

    module RemoveRedundantParens
      def param_seq
        super.sub(/^\(\)\s*/, "")
      end
    end

    # render "[label] data" lists as tables.  adapted from "hanna-nouveau" gem.
    module LabelListTable
      def list_item_start(list_item, list_type)
        case list_type
        when :NOTE
          %(<tr><td class='label'>#{Array(list_item.label).map{|label| to_html(label)}.join("<br />")}</td><td>)
        else
          super
        end
      end

      def list_end_for(list_type)
        case list_type
        when :NOTE then
          "</td></tr>"
        else
          super
        end
      end
    end

  end
end

class RDoc::AnyMethod
  prepend RDoc::Generator::NetIMAP::RemoveRedundantParens
end

class RDoc::Markup::ToHtml
  LIST_TYPE_TO_HTML[:NOTE] = ['<table class="rdoc-list note-list"><tbody>', '</tbody></table>']
  prepend RDoc::Generator::NetIMAP::LabelListTable
end

(RDoc::Parser::Ruby::RDocVisitor rescue nil)
  &.prepend RDoc::Generator::NetIMAP::FixPrismParserAttrVisitor

RDoc::Task.new do |doc|
  doc.title      = "net-imap #{Net::IMAP::VERSION}"
  doc.rdoc_dir   = "doc"
  doc.options << "--template-stylesheets" << "docs/styles.css"
  doc.generator  = "darkfish" # TODO: fix issues with aliki
end
