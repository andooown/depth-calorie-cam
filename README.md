# DepthCalorieCam

## How to
### Develop
1. Clone this repository.
    ```
    $ git clone git@github.com:andooown/depth-calorie-cam.git
    ```
2. Install required gems via bundler.
    ```
    $ bundle install --path vendor/bundle
    ```

### Develop and Publish
**Note:** To publish on App Store with fastlane, You need permission for [depth-calorie-cam-fastlane](https://github.com/andooown/depth-calorie-cam-fastlane) repository.
1. Clone this repository with publish information.
    ```
    $ git clone --recursive git@github.com:andooown/depth-calorie-cam.git
    ```
2. Install required gems via bundler.
    ```
    $ bundle install --path vendor/bundle
    ```
3. Run "release" lane to publish.
    ```
    $ bundle exec fastlane release
    ```
