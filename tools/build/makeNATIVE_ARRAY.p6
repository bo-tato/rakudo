#!/usr/bin/env perl6

# This script reads the native_array.pm6 file from STDIN, and generates the
# intarray, numarray and strarray roles in it, and writes it to STDOUT.

use v6;

my $generator = $*PROGRAM-NAME;
my $generated = DateTime.now.gist.subst(/\.\d+/,'');
my $start     = '#- start of generated part of ';
my $idpos     = $start.chars;
my $idchars   = 3;
my $end       = '#- end of generated part of ';

# for all the lines in the source that don't need special handling
for $*IN.lines -> $line {

    # nothing to do yet
    unless $line.starts-with($start) {
        say $line;
        next;
    }

    # found shaped header, ignore
    my $type = $line.substr($idpos,$idchars);
    if $type eq 'sha' {
        say $line;
        next;
    }

    # found header
    die "Don't know how to handle $type" unless $type eq "int" | "num" | "str";
    say $start ~ $type ~ "array role -----------------------------------";
    say "#- Generated on $generated by $generator";
    say "#- PLEASE DON'T CHANGE ANYTHING BELOW THIS LINE";

    # skip the old version of the code
    for $*IN.lines -> $line {
        last if $line.starts-with($end);
    }

    # set up template values
    my %mapper =
      postfix => $type.substr(0,1),
      type    => $type,
      Type    => $type.tclc,
    ;

    # spurt the role
    say Q:to/SOURCE/.subst(/ '#' (\w+) '#' /, -> $/ { %mapper{$0} }, :g).chomp;

        multi method AT-POS(#type#array:D: int $idx) is raw {
            nqp::atposref_#postfix#(self, $idx)
        }
        multi method AT-POS(#type#array:D: Int:D $idx) is raw {
            nqp::atposref_#postfix#(self, $idx)
        }

        multi method ASSIGN-POS(#type#array:D: int $idx, #type# $value) {
            nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Int:D $idx, #type# $value) {
            nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: int $idx, #Type#:D $value) {
            nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Int:D $idx, #Type#:D $value) {
            nqp::bindpos_#postfix#(self, $idx, $value)
        }
        multi method ASSIGN-POS(#type#array:D: Any $idx, Mu \value) {
            X::TypeCheck.new(
                operation => "assignment to #type# array element #$idx",
                got       => value,
                expected  => T,
            ).throw;
        }

        multi method STORE(#type#array:D: $value) {
            nqp::setelems(self,1);
            nqp::bindpos_#postfix#(self, 0, nqp::unbox_#postfix#($value));
            self
        }
        multi method STORE(#type#array:D: #type#array:D \values) {
            nqp::setelems(self,nqp::elems(values));
            nqp::splice(self,values,0,nqp::elems(values))
        }
        multi method STORE(#type#array:D: Seq:D \seq) {
            nqp::if(
              (my $iterator := seq.iterator).is-lazy,
              Failure.new(X::Cannot::Lazy.new(
                :action<store>, :what(self.^name)
              )),
              nqp::stmts(
                $iterator.push-all(self),
                self
              )
            )
        }
        multi method STORE(#type#array:D: List:D \values) {
            my int $elems = values.elems;    # reifies
            my \reified := nqp::getattr(values,List,'$!reified');
            nqp::setelems(self, $elems);

            my int $i = -1;
            nqp::while(
              nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
              nqp::bindpos_#postfix#(self, $i,
                nqp::unbox_#postfix#(nqp::atpos(reified,$i)))
            );
            self
        }
        multi method STORE(#type#array:D: @values) {
            my int $elems = @values.elems;   # reifies
            nqp::setelems(self, $elems);

            my int $i = -1;
            nqp::while(
              nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
              nqp::bindpos_#postfix#(self, $i,
                nqp::unbox_#postfix#(@values.AT-POS($i)))
            );
            self
        }

        multi method push(#type#array:D: #type# $value) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method push(#type#array:D: #Type#:D $value) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method push(#type#array:D: Mu \value) {
            X::TypeCheck.new(
                operation => 'push to #type# array',
                got       => value,
                expected  => T,
            ).throw;
        }
        multi method append(#type#array:D: #type# $value) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method append(#type#array:D: #Type#:D $value) {
            nqp::push_#postfix#(self, $value);
            self
        }
        multi method append(#type#array:D: #type#array:D $values) is default {
            nqp::splice(self,$values,nqp::elems(self),0)
        }
        multi method append(#type#array:D: @values) {
            fail X::Cannot::Lazy.new(:action<append>, :what(self.^name))
              if @values.is-lazy;
            nqp::push_#postfix#(self, $_) for flat @values;
            self
        }

        method pop(#type#array:D: --> #type#) {
            nqp::elems(self)
              ?? nqp::pop_#postfix#(self)
              !! die X::Cannot::Empty.new(:action<pop>, :what(self.^name));
        }

        method shift(#type#array:D: --> #type#) {
            nqp::elems(self)
              ?? nqp::shift_#postfix#(self)
              !! die X::Cannot::Empty.new(:action<shift>, :what(self.^name));
        }

        multi method unshift(#type#array:D: #type# $value) {
            nqp::unshift_#postfix#(self, $value);
            self
        }
        multi method unshift(#type#array:D: #Type#:D $value) {
            nqp::unshift_#postfix#(self, $value);
            self
        }
        multi method unshift(#type#array:D: @values) {
            fail X::Cannot::Lazy.new(:action<unshift>, :what(self.^name))
              if @values.is-lazy;
            nqp::unshift_#postfix#(self, @values.pop) while @values;
            self
        }
        multi method unshift(#type#array:D: Mu \value) {
            X::TypeCheck.new(
                operation => 'unshift to #type# array',
                got       => value,
                expected  => T,
            ).throw;
        }

        my $empty_#postfix# := nqp::list_#postfix#;

        multi method splice(#type#array:D:) {
            my $splice := nqp::clone(self);
            nqp::setelems(self,0);
            $splice
        }
        multi method splice(#type#array:D: Int:D \offset) {
            nqp::if(
              nqp::islt_i((my int $offset = offset),0)
                || nqp::isgt_i($offset,(my int $elems = nqp::elems(self))),
              Failure.new(X::OutOfRange.new(
                :what('Offset argument to splice'),
                :got($offset),
                :range("0..{nqp::elems(array)}")
              )),
              nqp::if(
                nqp::iseq_i($offset,nqp::elems(self)),
                nqp::create(self.WHAT),
                nqp::stmts(
                  (my $slice := nqp::slice(self,$offset,-1)),
                  nqp::splice(
                    self,
                    $empty_#postfix#,
                    $offset,
                    nqp::sub_i(nqp::elems(self),$offset)
                  ),
                  $slice
                )
              )
            )
        }
        multi method splice(#type#array:D: Int:D $offset, Int:D $size) {
            nqp::unless(
              nqp::istype(
                (my $slice := CLONE_SLICE(self,$offset,$size)),
                Failure
              ),
              nqp::splice(self,$empty_#postfix#,$offset,$size)
            );
            $slice
        }
        multi method splice(#type#array:D: Int:D $offset, Int:D $size, #type#array:D \values) {
            nqp::unless(
              nqp::istype(
                (my $slice := CLONE_SLICE(self,$offset,$size)),
                Failure
              ),
              nqp::splice(
                self,
                nqp::if(nqp::eqaddr(self,values),nqp::clone(values),values),
                $offset,
                $size
              )
            );
            $slice
        }
        multi method splice(#type#array:D: Int:D $offset, Int:D $size, Seq:D \seq) {
            nqp::if(
              seq.is-lazy,
              Failure.new(X::Cannot::Lazy.new(
                :action<splice>, :what(self.^name)
              )),
              nqp::stmts(
                nqp::unless(
                  nqp::istype(
                    (my $slice := CLONE_SLICE(self,$offset,$size)),
                    Failure
                  ),
                  nqp::splice(self,nqp::create(self).STORE(seq),$offset,$size)
                ),
                $slice
              )
            )
        }
        multi method splice(#type#array:D: $offset=0, $size=Whatever, *@values) {
            fail X::Cannot::Lazy.new(:action('splice in'))
              if @values.is-lazy;

            my int $elems = nqp::elems(self);
            my int $o = nqp::istype($offset,Callable)
              ?? $offset($elems)
              !! nqp::istype($offset,Whatever)
                ?? $elems
                !! $offset.Int;
            my int $s = nqp::istype($size,Callable)
              ?? $size($elems - $o)
              !! !defined($size) || nqp::istype($size,Whatever)
                 ?? $elems - ($o min $elems)
                 !! $size.Int;

            unless nqp::istype(
              (my $splice := CLONE_SLICE(self,$o,$s)),
              Failure
            ) {
                my $splicees := nqp::create(self);
                nqp::push_#postfix#($splicees, @values.shift) while @values;
                nqp::splice(self,$splicees,$o,$s);
            }
            $splice
        }

        multi method min(#type#array:D:) {
            nqp::if(
              (my int $elems = nqp::elems(self)),
              nqp::stmts(
                (my int $i),
                (my #type# $min = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::islt_#postfix#(nqp::atpos_#postfix#(self,$i),$min),
                    ($min = nqp::atpos_#postfix#(self,$i))
                  )
                ),
                $min
              ),
              Inf
            )
        }
        multi method max(#type#array:D:) {
            nqp::if(
              (my int $elems = nqp::elems(self)),
              nqp::stmts(
                (my int $i),
                (my #type# $max = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::isgt_#postfix#(nqp::atpos_#postfix#(self,$i),$max),
                    ($max = nqp::atpos_#postfix#(self,$i))
                  )
                ),
                $max
              ),
              -Inf
            )
        }
        multi method minmax(#type#array:D:) {
            nqp::if(
              (my int $elems = nqp::elems(self)),
              nqp::stmts(
                (my int $i),
                (my #type# $min =
                  my #type# $max = nqp::atpos_#postfix#(self,0)),
                nqp::while(
                  nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                  nqp::if(
                    nqp::islt_#postfix#(nqp::atpos_#postfix#(self,$i),$min),
                    ($min = nqp::atpos_#postfix#(self,$i)),
                    nqp::if(
                      nqp::isgt_#postfix#(nqp::atpos_#postfix#(self,$i),$max),
                      ($max = nqp::atpos_#postfix#(self,$i))
                    )
                  )
                ),
                Range.new($min,$max)
              ),
              Range.new(Inf,-Inf)
            )
        }

        method iterator(#type#array:D:) {
            class :: does Iterator {
                has int $!i;
                has $!array;    # Native array we're iterating

                method !SET-SELF(\array) {
                    $!array := nqp::decont(array);
                    $!i = -1;
                    self
                }
                method new(\array) { nqp::create(self)!SET-SELF(array) }

                method pull-one() is raw {
                    ($!i = $!i + 1) < nqp::elems($!array)
                      ?? nqp::atposref_#postfix#($!array,$!i)
                      !! IterationEnd
                }
                method skip-one() {
                    ($!i = $!i + 1) < nqp::elems($!array)
                }
                method skip-at-least(int $toskip) {
                    nqp::unless(
                      ($!i = $!i + $toskip) < nqp::elems($!array),
                      nqp::stmts(
                        ($!i = nqp::elems($!array)),
                        0
                      )
                    )
                }
                method push-all($target --> IterationEnd) {
                    my int $i     = $!i;
                    my int $elems = nqp::elems($!array);
                    nqp::while(
                      nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                      $target.push(nqp::atposref_#postfix#($!array,$i))
                    );
                    $!i = $i;
                }
            }.new(self)
        }
        method reverse(#type#array:D:) is nodal {
            nqp::stmts(
              (my int $elems = nqp::elems(self)),
              (my int $last  = nqp::sub_i($elems,1)),
              (my int $i     = -1),
              (my $to := nqp::clone(self)),
              nqp::while(
                nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                nqp::bindpos_#postfix#($to,nqp::sub_i($last,$i),
                  nqp::atpos_#postfix#(self,$i))
              ),
              $to
            )
        }
        method rotate(#type#array:D: Int(Cool) $rotate = 1) is nodal {
            nqp::stmts(
              (my int $elems = nqp::elems(self)),
              (my $to := nqp::clone(self)),
              (my int $i = -1),
              (my int $j =
                nqp::mod_i(nqp::sub_i(nqp::sub_i($elems,1),$rotate),$elems)),
              nqp::if(nqp::islt_i($j,0),($j = nqp::add_i($j,$elems))),
              nqp::while(
                nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
                nqp::bindpos_#postfix#(
                  $to,
                  ($j = nqp::mod_i(nqp::add_i($j,1),$elems)),
                  nqp::atpos_#postfix#(self,$i)
                ),
              ),
              $to
            )
        }
        multi method sort(#type#array:D:) {
            Rakudo::Sorting.MERGESORT-#type#(nqp::clone(self))
        }

        multi method ACCEPTS(#type#array:D: #type#array:D \other) {
            nqp::p6bool(
              nqp::unless(
                nqp::eqaddr(self,other),
                nqp::if(
                  nqp::iseq_i(
                    (my int $elems = nqp::elems(self)),
                    nqp::elems(other)
                  ),
                  nqp::stmts(
                    (my int $i = -1),
                    nqp::while(
                      nqp::islt_i(($i = nqp::add_i($i,1)),$elems)
                        && nqp::iseq_#postfix#(
                             nqp::atpos_#postfix#(self,$i),
                             nqp::atpos_#postfix#(other,$i)
                           ),
                      nqp::null
                    ),
                    nqp::iseq_i($i,$elems)
                  )
                )
              )
            )
        }
        proto method grab(|) {*}
        multi method grab(#type#array:D:) {
            nqp::if(nqp::elems(self),self.GRAB_ONE,Nil)
        }
        multi method grab(#type#array:D: Callable:D $calculate) {
            self.grab($calculate(nqp::elems(self)))
        }
        multi method grab(#type#array:D: Whatever) { self.grab(Inf) }
        multi method grab(#type#array:D: $count) {
            Seq.new(nqp::if(
              nqp::elems(self),
              class :: does Iterator {
                  has $!array;
                  has int $!count;

                  method !SET-SELF(\array,\count) {
                      nqp::stmts(
                        (my int $elems = nqp::elems(array)),
                        ($!array := array),
                        nqp::if(
                          count == Inf,
                          ($!count = $elems),
                          nqp::if(
                            nqp::isgt_i(($!count = count.Int),$elems),
                            ($!count = $elems)
                          )
                        ),
                        self
                      )

                  }
                  method new(\a,\c) { nqp::create(self)!SET-SELF(a,c) }
                  method pull-one() {
                      nqp::if(
                        $!count && nqp::elems($!array),
                        nqp::stmts(
                          ($!count = nqp::sub_i($!count,1)),
                          $!array.GRAB_ONE
                        ),
                        IterationEnd
                      )
                  }
              }.new(self,$count),
              Rakudo::Iterator.Empty
            ))
        }

        method GRAB_ONE(#type#array:D:) {
            nqp::stmts(
              (my $value := nqp::atpos_#postfix#(
                self,
                (my int $pos = nqp::floor_n(nqp::rand_n(nqp::elems(self))))
              )),
              nqp::splice(self,$empty_#postfix#,$pos,1),
              $value
            )
        }
SOURCE

    # we're done for this role
    say "#- PLEASE DON'T CHANGE ANYTHING ABOVE THIS LINE";
    say $end ~ $type ~ "array role -------------------------------------";
}
