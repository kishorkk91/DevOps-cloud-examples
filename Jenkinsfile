pipeline {
    agent any
    tools {
        go 'Go1.8.3'
    }

    // any global variables are defined here.
    environment {
        CUSTOMER_REPOSITORY = 'reg-dhc.app.CUSTOMER_REPOSITORY'
        DEV_REPOSITORY = 'Path of GCP repository'
        APP = 'AppName'
        MIN_COVERAGE = '85'
        SRC = 'src/gitlab.team.de/full-project-path'
    }

    stages {
        // first, do any initialization
        // in this case we are logging into docker in the development environment and on DHC
        // make sure that these login scripts exist
        stage ('Initialize') {
            steps {
                script {
                    def props = readProperties file:'version';
                    env.version = props['version'];
                    env.DATE = new Date().format('yyyyMMdd')
                    def gitCommit = env['GIT_COMMIT']
                    env.SHORTCOMMIT = gitCommit[0..6]
                    env.DOCKERVERSION = "${env.version}.${env.DATE}-${env.SHORTCOMMIT}"
                    env.DOCKERIMG = "${DEV_REPOSITORY}/${APP}:${env.version}.${env.DATE}-${env.SHORTCOMMIT}"
                    env.DHCDOCKERIMG = "${CUSTOMER_REPOSITORY}/${APP}:${env.version}.RELEASE"
                }
            }
        }
        stage ('Build go application') {
            steps {
                sh '''
                    DIR=$GOPATH/$SRC
                    echo "copy project to $DIR"
                    rm -rf "$DIR"
                    mkdir -p "$DIR"
                    cp -r $PWD/* $DIR/
                    cd "$DIR"

                    echo "getting go dependencies"
                    go get -u github.com/golang/dep/cmd/dep
                    dep ensure

                    echo "building go application"
                    CGO_ENABLED=1 GOOS=linux go build -ldflags "-s -w" -o ${WORKSPACE}/${APP} .
                '''
            }
        }
        stage ('Run go tests with coverage') {
            steps {
                sh '''
                    DIR=$GOPATH/$SRC
                    cd "$DIR"
                    echo "running go tests with coverage check"
                '''
                script {
                    def testFolders = sh (
                    script: "cd $GOPATH/$SRC && go list ./... | grep -v /vendor/",
                    returnStdout: true
                    ).trim()
                    foldersList = testFolders.tokenize("\n")
                    for (def pkg in foldersList){
                        def test_coverage_statement = sh (
                        script: "go test -coverprofile=cover.out ${pkg}",
                        returnStdout: true
                        ).trim()
                       if(test_coverage_statement.contains("%")){
                            println test_coverage_statement
                            test_coverage_first_part = test_coverage_statement.split("%")[0]
                            test_coverage_percentage = test_coverage_first_part.reverse().take(5).reverse()
                            if (test_coverage_percentage.contains(":")){
                                test_coverage_percentage_digits = test_coverage_percentage.tokenize(":")
                                def test_coverage_percentage_float1 = test_coverage_percentage_digits[0] as Float
                                if ((test_coverage_percentage_float1.compareTo(MIN_COVERAGE as Float)) == (-1)){
                                    throw new Exception("Test coverage is ${test_coverage_percentage_float1}, i.e. below ${MIN_COVERAGE} for ${pkg}")
                                }
                            } else {
                                def test_coverage_percentage_float = "$test_coverage_percentage" as Float
                                if ((test_coverage_percentage_float.compareTo(MIN_COVERAGE as Float)) == (-1)){
                                    throw new Exception("Test coverage is ${test_coverage_percentage_float}, i.e. below ${MIN_COVERAGE} for ${pkg}")
                                }
                            }
                       }
                    }
                }
            }
        }

        stage ('Build, tag and push docker image') {
            steps {
                    sh """
                        /home/ciu/bin/docker-gcloud-login

                        docker build -t ${env.DOCKERIMG} .
                        docker push ${env.DOCKERIMG}

                        /home/ciu/bin/docker-gcloud-logout
                    """
            }
        }

        // deploy on dev
        // in this case we are using helm to:
        // 1. Check the charts
        // 2. Do a dry run and print the information
        // 3. Do the actual deploy on the dev environment

        // NOTE: remember to add --kube-context and --namespace in the Helm arguments if appropriate!

        stage ('Deploy to dev') {
            steps {
                sh """
                    echo "running helm lint"
                    helm lint ./chart/${APP}

                    echo "helm dry run"
                    helm upgrade --install --dry-run ${APP} ./chart/${APP} \
                        --set image=${env.DOCKERIMG},version=${env.version},containerPort=8080,service.type=ClusterIP,CORESNAPSHOTSURL="https://automotive-dev.de/snapshots/v1",APPDYNAMICS_CONTROLLER_HOST=,APPDYNAMICS_CONTROLLER_PORT=,APPDYNAMICS_CONTROLLER_ACCOUNT=,APPDYNAMICS_CONTROLLER_ACCESS_KEY=,APPDYNAMICS_CONTROLLER_USE_SSL=true --namespace vds --kube-context gke_automotive-test-cluster --debug

                    echo "helm deployment"
                    helm upgrade --install --wait ${APP} ./chart/${APP} \
                        --set image=${env.DOCKERIMG},version=${env.version},containerPort=8080,service.type=ClusterIP,CORESNAPSHOTSURL="https://automotive-dev.de/snapshots/v1",APPDYNAMICS_CONTROLLER_HOST=,APPDYNAMICS_CONTROLLER_PORT=,APPDYNAMICS_CONTROLLER_ACCOUNT=,APPDYNAMICS_CONTROLLER_ACCESS_KEY=,APPDYNAMICS_CONTROLLER_USE_SSL=true --namespace vds --kube-context gke_automotive-test-cluster --debug

                    echo "packaging chart"
                    helm package ./chart/${APP}

                    echo "application ${APP} successfully deployed"
                """
            }
        }

        stage ('Run smoke tests on dev') {
            steps {
                echo "running smoke tests"
                sh '''
                    newman run IT-Tests/smoketest.json -e IT-Tests/dev_business-snapshots.json
                '''
            }
        }

        // If the current branch is master, we can choose to deploy to INT or PROD.
        // This popup will show up in Jenkins.
        stage ('Choose deployment') {
            when { branch 'master' }
            steps {
                script {
                    env.TARGET_ENV = input message: 'User input required', ok: 'Release!',
                        parameters: [choice(name: 'TARGET_ENV', choices: "int\nprod\nboth", description: 'Where to deploy to?')]
                }
                echo "deploying to ${TARGET_ENV}"
            }
        }

        // Save prepared release to local repository
        stage ('Saving chart to chartmuseum') {
            when { branch 'master' }
            steps {
                script {
                    // need to find the package name
                    def filename = sh(script: '''find . -name "*.tgz"''', returnStdout: true).trim()
                    env.chartname = filename.substring(2)
                }
                sh """
                    echo "now saving ${env.chartname}"
                    curl --data-binary "@${env.chartname}" ${CHART_MUSEUM}

                    echo "deleting generated package"
                    rm -f ${env.chartname}
                """
            }
        }

        // If we are deploying to INT or PROD, then tag the release to its new repository image name.
        // Uncomment the shell script comments to really tag!
        // Change the login/logout so it's specific to your project!
        stage('tag and push image to Client') {
            when {
                anyOf { environment name: 'TARGET_ENV', value: 'int';environment name: 'TARGET_ENV', value: 'both'; environment name: 'TARGET_ENV', value: 'prod'  }
            }
            steps {
                echo 'retagging docker image'
                sh """
                    docker tag ${env.DOCKERIMG}  ${env.DHCDOCKERIMG}
                    /home/ciu/bin/docker-DHC-vds-login && docker push ${env.DHCDOCKERIMG} && /home/ciu/bin/docker-DHC-vds-logout
                """
            }
        }

        // If we are deploying to INT, then deploy!
        // Get rid of the --dry-run to really deploy!
        // TODO: smoke tests
        // make sure your namespace, kube-context, and tiller-namespace is correct!
        stage('deploy int') {
            when {
                anyOf { environment name: 'TARGET_ENV', value: 'int'; environment name: 'TARGET_ENV', value: 'both' }
            }
            steps {
                echo 'deploying to int'
                sh """
                echo "dry run"
                helm upgrade --install --dry-run ${APP}  --wait ./chart/${APP}   \
                            --kube-context vds-int --namespace data-business --tiller-namespace default \
                echo "helm deployment"
                helm upgrade --install ${APP}  --wait ./chart/${APP}   \
                            --kube-context vds-int --namespace data-business --tiller-namespace default \
                """
            }
        }

        // If we are deploying to PROD, then deploy!
        // Get rid of the --dry-run to really deploy!
        // TODO: smoke tests
        // make sure your namespace, kube-context, and tiller-namespace is correct!
         stage('deploy prod') {
             when {
                 anyOf { environment name: 'TARGET_ENV', value: 'prod';environment name: 'TARGET_ENV', value: 'both' }
             }
             steps {
                 echo 'deploying to prod'
                 sh """
                 echo "dry run"
                 helm upgrade --install --dry-run ${APP}  --wait ./chart/${APP}   \
                              --kube-context vds-prod --namespace data-business --tiller-namespace default \
                 echo "helm deployment"
                 helm upgrade --install ${APP}  --wait ./chart/${APP}   \
                              --kube-context vds-prod --namespace data-business --tiller-namespace default \
                 """
             }
         }
    }
}