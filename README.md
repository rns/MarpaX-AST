MarpaX-AST
==========

Abstract Syntax Tree (AST) for Marpa::R2

check for endless loop
    max_parses
non-recursive traversal
pretty printing
benchmark with MarpaX::Languages::JSON::AST

why?
    because its arguably faster and more elegant, if less simple, 
    way to do semantics when parsing with Marpa::R2::Scanless (SLIF) interface,
    if you've got used to working with trees.

```    
        my $p = MarpaX::AST->new( 
            $grammar_source,
            {
                source      => $grammar_source
                whitespaces => 1    # preserve whitespaces
                spans       => 1    # input spans (start and length)
                                    # will be put in parse trees nodes
                                    # [ node_id, start, length, value ]
                grammar_option(s) => value     # to be passed to the grammar   
                recognizer_option(s) => value  # to be passed to the recognizer
            }
        );
        
        # Marpa::R2::Scanless::G::parse() with a twist
        my $ast = $p->parse( $input, { recognizer options } );
```    

features

    uniquify 
        node ids unique across grammar for dispatching
        when both symbol and name are specified
        [ symbol, name, ... values ]
        name or 'symbol/name' if symbol isn't unique
    
    ast walker code/handlers generation for a given grammar
        as a table of handlers
            handlers => {
                'symbol' => sub { }
            }
        as a recursive function
            sub process {
                if ($symbol eq 'symbol'){
                    ...
                }
                elsif ($symbol eq 'another_symbol'){
                    ...
                }
            }
    
    reversal
        change children to parents
        http://www.ardendertat.com/2011/12/08/programming-interview-questions-21-tree-reverse-level-order-print/
        
    non-recursive traversing
        beat jdd's JSON parser (hopefully)!
    
    pretty printing

        show
        show_compact
    
    traversing in context with in-place transforms via parent
    
        traverse(
            $traverser,
            qw{ parent depth ... }
        )

        $traverser->( $node, $context );
            node
                class
                value(s)

            context
                - configurable via call to traverser
                parent
                depth
                path (you are here)
                index

    visualization
        http://blog.reverberate.org/2008/02/what-best-way-to-visualize-parse-tree.html

    indexing
    fragments
    
    flattening
    
```
        sub flatten {
            my ($tree) = @_;
            if ( ref $tree eq 'REF' ) { return flatten( ${$tree} ); }
            if ( ref $tree eq 'ARRAY' ) {
                return [ map { @{ flatten($_) } } @{$tree} ];
            }
            return [$tree];
        } ## end sub flatten
```        
        https://gist.github.com/jeffreykegler/ed64bf00983f7be666bc

        - turn single element arrays ([value]) to elements of parent array
        
tests   
    sl_astsyn.t
    sl_timeflies_ast.t
    sl_json_ast.t

    -
        bin/parse grammar-file-or-stdin input-file-or-stdin
        -- show ast
        -- marpa REPL
            - load grammar
            - parse input
            - show ast
            - edit grammar in external editor
            - edit input
            $EDITOR


```    
    node = [ 'node_id', values ]

    value = scalar or array_ref

    node[i][j] -- 

        S/0: “
        S/1/quoted/0/quoted/0/quoted/0/item/0/unquoted: 'these are '
        S/1/quoted/0/quoted/1/item/0/S/0: “
        S/1/quoted/0/quoted/1/item/0/S/1/quoted/0/item/0/unquoted: words in curly double quotes
        S/1/quoted/0/quoted/1/item/0/S/2: ”
        S/1/quoted/1/item/0/unquoted: ' and then some'
        S/2: ”

    quoted[2][1] == item
```

* Why use parse trees

    Parse trees are an in-memory representation of the input with a structure that conforms to the grammar.

    The advantages of using parse trees instead of semantic actions:

    - You can make multiple passes over the data without having to re-parse the input.
    - You can perform transformations on the tree.
    - You can evaluate things in any order you want, whereas with attribute schemes you have to process in a begin to end fashion.
    - You do not have to worry about backtracking and action side effects that may occur with an ambiguous grammar.

    = http://www.boost.org/doc/libs/1_34_0/libs/spirit/doc/trees.html

