Autotest.add_hook(:initialize) {|at|
  at.add_exception %r{^\.git}  # ignore Version Control System
  at.add_exception %r{^./tmp}  # ignore temp files, lest autotest will run again, and again...
  #  at.clear_mappings         # take out the default (test/test*rb)
  at.add_mapping(%r{^lib/.*\.rb$}) {|f, _|
    Dir['spec/**/*.rb']
  }
  nil
}