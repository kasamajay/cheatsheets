└── ansible
    ├── environments
    │   ├── 000_all_vars
    │   ├── dev
    │   │   └── group_vars
    │   │       └── all
    │   │           ├── 000_all_vars -> ../../../000_all_vars
    │   │           └── vars.yml
    │   └── prod
    │       └── group_vars
    │           └── all
    │               └── vars.yml
    ├── playbooks
    │   └── play-1.yml
    └── roles
        └── role-1
            ├── defaults
            │   └── main.yml
            ├── tasks
            │   └── main.yml
            └── templates
                └── t1.yml.j2
                
    ln -s ../../../000_all_vars 000_all_vars
