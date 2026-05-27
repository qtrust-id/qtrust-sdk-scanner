pipeline {
    agent {
        label 'macos' // Requires macOS agent with Xcode installed
    }

    environment {
        SCHEME       = 'QTrustScanner'
        SDK_VERSION  = '1.0.0'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Resolve Dependencies') {
            steps {
                sh 'swift package resolve'
            }
        }

        stage('Build') {
            steps {
                sh 'swift build'
            }
        }

        stage('Test') {
            steps {
                sh 'swift test --enable-code-coverage'
            }
        }

        stage('Archive XCFramework') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                sh '''
                    set -e

                    # Build for iOS device
                    xcodebuild archive \
                        -scheme ${SCHEME} \
                        -destination "generic/platform=iOS" \
                        -archivePath build/ios.xcarchive \
                        SKIP_INSTALL=NO \
                        BUILD_LIBRARY_FOR_DISTRIBUTION=YES

                    # Build for iOS Simulator
                    xcodebuild archive \
                        -scheme ${SCHEME} \
                        -destination "generic/platform=iOS Simulator" \
                        -archivePath build/sim.xcarchive \
                        SKIP_INSTALL=NO \
                        BUILD_LIBRARY_FOR_DISTRIBUTION=YES

                    # Create XCFramework
                    xcodebuild -create-xcframework \
                        -framework build/ios.xcarchive/Products/Library/Frameworks/${SCHEME}.framework \
                        -framework build/sim.xcarchive/Products/Library/Frameworks/${SCHEME}.framework \
                        -output build/${SCHEME}.xcframework

                    # Zip for distribution
                    cd build && zip -r ${SCHEME}-${SDK_VERSION}.xcframework.zip ${SCHEME}.xcframework
                '''
            }
        }

        stage('Archive Artifacts') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                archiveArtifacts artifacts: "build/${SCHEME}-${SDK_VERSION}.xcframework.zip", fingerprint: true
            }
        }
    }

    post {
        failure {
            echo "Build failed: ${env.BUILD_URL}"
        }
        always {
            sh 'rm -rf build/'
        }
    }
}
