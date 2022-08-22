project('portage', 'd')

ssources = ['source/portage.d']
lib = library('subcmds', 'source/subs.d')

res = run_command(['git', 'log', '--format="%H"', '-n', '1'], capture : true, check : true)
sig = res.stdout().strip()

run_command(['./export_version.sh', sig])

executable('portage', 
            ['source/subs.d', 'source/portage.d', 'source/gitversion.d'],
            
            install : true)
