#!/bin/bash

# Arguments: the FDroid build script variables:
#  * $$VERSION$$
#  * $$VERCODE$$

version=$1
vercode=$2
native_lib_arch=$3

# Changes marked
#   - BUILD: required for FDroid build
#   - COSMETIC: tidy up app to hide necessary FDroid changes
#   - CUSTOM: bespoke customisations from FDroid user requests

# Fail on any error

set -e

# Always start from the directory this script is in

script_dir="$(dirname -- "$( readlink -f -- "$0"; )")";
pushd "$script_dir"

build_dir="$script_dir/build"
android_dir="$script_dir/android"
osmand_dir="$android_dir/OsmAnd"
osmand_java_dir="$android_dir/OsmAnd-java"
core_legacy_dir="$script_dir/core-legacy"
core_dir="$script_dir/core"
stubs_dir="$script_dir/stubs"
mpchartlib_dir="$script_dir/MPAndroidChart"
icu_dir="$script_dir/icu-release-50-2-1-patched-mirror"

# BUILD: Install the Android SDK Platform API level 31, which is required for qtbase-android (OsmAnd core).
sdkmanager "platforms;android-31"

# BUILD: Add the ANDROID_SDK export because the auto-detection in src/corelib/Qt5AndroidSupport.cmake (qtbase-android) fails. This is due to our SDK/NDK paths being structured as .../sdk/ndk/<ndk-version>, whereas .../sdk/ndk is expected.
sed -i '/set(ANDROID_SDK_BUILD_TOOLS_REVISION "$ENV{ANDROID_SDK_BUILD_TOOLS_REVISION}")/a set(ANDROID_SDK "$ENV{ANDROID_HOME}" CACHE STRING "Android SDK path")' "$build_dir/targets/android-ndk-clang.cmake"

# BUILD: Add enough memory for the build on FDroid
echo -e "\norg.gradle.jvmargs=-XX:MaxHeapSize=4096m" \
    >> "$android_dir/gradle.properties"

# BUILD: Remove OsmAnd self-hosted ivy binary repository.
sed -i \
    -e "/ivy {/,+6d" \
    "$android_dir/build.gradle"

# BUILD: Remove maven publishing as it trips up the build now.
sed -i \
    -e "/publishing {/,+18d" \
    "$osmand_java_dir/build.gradle"

# BUILD: Sub in the right build information (version/appname)
sed -i \
    -e "s/System.getenv(\"APK_VERSION\")/\"$version\"/g" \
    "$osmand_dir/build.gradle"
sed -i \
    -e "s/System.getenv(\"APK_NUMBER_VERSION\")/\"$vercode\"/g" \
    "$osmand_dir/build.gradle"
sed -i \
    -e "s/System.getenv(\"TARGET_APP_NAME\")/\"OsmAnd~\"/g" \
    "$osmand_dir/build.gradle"

# BUILD: Remove upstream non-free code including self-hosted pre-built
# binaries. In particular, the OsmAnd core renderer and company code for
# e.g. billing.
sed -i \
    -e "/.*mplementation.*OsmAndCore.*/d" \
    -e "/play-services-location/d" \
    -e '/MPAndroidChart/d' \
    "$osmand_dir/build-common.gradle"
sed -i \
    -e "/.*mplementation.*OsmAndCore.*/d" \
    -e "/play-services-location/d" \
    -e '/MPAndroidChart/d' \
    "$osmand_dir/build-library.gradle"

sed -i \
    -e "/.*com.google.android.play.*/d" \
    "$osmand_dir/build-common.gradle"

perl -i -0 -p \
    -e "s|maven\s*\{[^}]*?url\s+'https://developer\.huawei\.com/repo/'[^}]*?content\s*\{[^}]*?\}[^}]*?\}||gs" \
    "$android_dir/build.gradle"
sed -i \
    -e "/huaweiImplementation/d" \
    "$osmand_dir/build.gradle"

sed -i \
    -e "s/, ':OsmAnd-telegram'//" \
    "$android_dir/settings.gradle"

sed -i \
    -e "/.*com.amazon.in-app-purchasing.*/d" \
    "$osmand_dir/build.gradle"
sed -i \
    -e "/.*com.android.billingclient.*/d" \
    "$osmand_dir/build-common.gradle"

# BUILD: remove ANT+ code from sensors framework
sed -i \
    -e "/.*antpluginlib.*/d" \
    "$osmand_dir/build-common.gradle"
rm -r "$osmand_dir/src/net/osmand/plus/plugins/externalsensors/devices/ant"
rm -r "$osmand_dir/src/net/osmand/plus/plugins/externalsensors/devices/sensors/ant"

patch "$osmand_dir/src/net/osmand/plus/plugins/externalsensors/DevicesHelper.java" <<-'EOF'
@@ -25,9 +25,6 @@
 import androidx.annotation.NonNull;
 import androidx.annotation.Nullable;
 
-import com.dsi.ant.plugins.antplus.pcc.AntPlusHeartRatePcc;
-import com.dsi.ant.plugins.antplus.pccbase.AntPluginPcc;
-
 import net.osmand.PlatformUtil;
 import net.osmand.plus.OsmandApplication;
 import net.osmand.plus.R;
@@ -39,12 +36,6 @@
 import net.osmand.plus.plugins.externalsensors.devices.AbstractDevice;
 import net.osmand.plus.plugins.externalsensors.devices.AbstractDevice.DeviceListener;
 import net.osmand.plus.plugins.externalsensors.devices.DeviceConnectionResult;
-import net.osmand.plus.plugins.externalsensors.devices.ant.AntAbstractDevice;
-import net.osmand.plus.plugins.externalsensors.devices.ant.AntBikePowerDevice;
-import net.osmand.plus.plugins.externalsensors.devices.ant.AntBikeSpeedCadenceDevice;
-import net.osmand.plus.plugins.externalsensors.devices.ant.AntBikeSpeedDistanceDevice;
-import net.osmand.plus.plugins.externalsensors.devices.ant.AntHeartRateDevice;
-import net.osmand.plus.plugins.externalsensors.devices.ant.AntTemperatureDevice;
 import net.osmand.plus.plugins.externalsensors.devices.ble.BLEAbstractDevice;
 import net.osmand.plus.plugins.externalsensors.devices.ble.BLEBPICPDevice;
 import net.osmand.plus.plugins.externalsensors.devices.ble.BLEBikeSCDDevice;
@@ -87,7 +78,6 @@
 	private OsmandApplication app;
 	protected DevicesSettingsCollection devicesSettingsCollection;
 	protected final Map<String, AbstractDevice<?>> devices = new ConcurrentHashMap<>();
-	private List<AntAbstractDevice<?>> antSearchableDevices = new ArrayList<>();
 
 	private boolean antScanning;
 	private boolean bleScanning;
@@ -182,11 +172,6 @@
 	@Nullable
 	protected AbstractDevice<?> createDevice(@NonNull DeviceType deviceType, @NonNull String deviceId, @NonNull DeviceSettings deviceSettings) {
 		return switch (deviceType) {
-			case ANT_HEART_RATE -> new AntHeartRateDevice(deviceId);
-			case ANT_TEMPERATURE -> new AntTemperatureDevice(deviceId);
-			case ANT_BICYCLE_POWER -> new AntBikePowerDevice(deviceId);
-			case ANT_BICYCLE_SC -> new AntBikeSpeedCadenceDevice(deviceId);
-			case ANT_BICYCLE_SD -> new AntBikeSpeedDistanceDevice(deviceId);
 			case BLE_OBD ->
 					bluetoothAdapter != null ? new BLEOBDDevice(bluetoothAdapter, deviceId) : null;
 			case BLE_TEMPERATURE ->
@@ -326,7 +311,7 @@
 
 	void updateDevice(@Nullable Activity activity, @NonNull AbstractDevice<?> device) {
 		if (isDeviceEnabled(device) && device.isDisconnected()) {
-			if (device instanceof AntAbstractDevice<?> || (activity != null && BLEUtils.INSTANCE.isBLEEnabled(activity))) {
+			if (activity != null && BLEUtils.INSTANCE.isBLEEnabled(activity)) {
 				connectDevice(activity, device);
 			}
 		} else if (!isDeviceEnabled(device) && device.isConnected()) {
@@ -352,7 +337,7 @@
 	}
 
 	boolean isAntDevice(@NonNull AbstractDevice<?> device) {
-		return device instanceof AntAbstractDevice<?>;
+		return false;
 	}
 
 	boolean isBLEDevice(@NonNull AbstractDevice<?> device) {
@@ -407,20 +392,6 @@
 	}
 
 	void askAntPluginInstall() {
-		if (activity == null || installAntPluginAsked) {
-			return;
-		}
-		AlertDialog.Builder builder = new AlertDialog.Builder(activity);
-		builder.setTitle(R.string.ant_missing_dependency);
-		builder.setMessage(app.getString(R.string.ant_missing_dependency_descr, AntPlusHeartRatePcc.getMissingDependencyName()));
-		builder.setCancelable(true);
-		builder.setPositiveButton(R.string.ant_go_to_store, (dialog, which) -> {
-			Uri uri = Uri.parse(Version.getUrlWithUtmRef(app, AntPluginPcc.getMissingDependencyPackageName()));
-			Intent intent = new Intent(Intent.ACTION_VIEW, uri);
-			AndroidUtils.startActivityIfSafe(activity, intent);
-		});
-		builder.setNegativeButton(R.string.shared_string_cancel, (dialog, which) -> dialog.dismiss());
-		builder.create().show();
 		installAntPluginAsked = true;
 	}
 
@@ -614,25 +585,6 @@
 	}
 
 	public void scanAntDevices(boolean enable) {
-		if (enable) {
-			antSearchableDevices = Arrays.asList(
-					AntTemperatureDevice.createSearchableDevice(),
-					AntHeartRateDevice.createSearchableDevice(),
-					AntBikeSpeedCadenceDevice.createSearchableDevice(),
-					AntBikeSpeedDistanceDevice.createSearchableDevice(app),
-					AntBikePowerDevice.createSearchableDevice());
-
-			for (AntAbstractDevice<?> device : antSearchableDevices) {
-				connectDevice(activity, device);
-			}
-			antScanning = true;
-		} else {
-			for (AntAbstractDevice<?> device : antSearchableDevices) {
-				disconnectDevice(device, false);
-			}
-			antSearchableDevices = new ArrayList<>();
-			antScanning = false;
-		}
 	}
 
 	@SuppressLint("MissingPermission")
EOF

# COSMETIC: add prohibited to ANT+ since we don't support it

sed -i \
    -e "s/ANT+/ANT+ (\&#x1F6AB;)/g" \
    "$osmand_dir"/res/**/strings.xml

# BUILD: Switch OsmAndCore_android to the OpenGL core built in build.sh

sed -i \
    -e "/opengldebugImplementation.*OsmAndCore.*/d" \
    -e "s!openglImplementation.*OsmAndCore_androidNativeRelease.*!openglImplementation\", files(\"libs/OsmAndCore_androidNativeRelease-release.aar\"))!" \
    -e "s!openglImplementation.*OsmAndCore_android:.*!openglImplementation\", files(\"libs/OsmAndCore_android-release.aar\"))!" \
    "$osmand_dir/build.gradle"

# BUILD: Set the compile versions for ICU to one supported by OpenJDK 21
sed -i "s/\^11/\^21/g" "$icu_dir/icu4j/build.xml"
sed -i "s/javac.source = 1.6/javac.source = 21/g" "$icu_dir/icu4j/main/shared/build/common.properties"
sed -i "s/javac.target = 1.6/javac.target = 21/g" "$icu_dir/icu4j/main/shared/build/common.properties"
sed -i "s/javac.source = 1.6/javac.source = 21/g" "$icu_dir/icu4j/main/classes/localespi/build.properties"
sed -i "s/javac.target = 1.6/javac.target = 21/g" "$icu_dir/icu4j/main/classes/localespi/build.properties"

# BUILD: remove MPChartLib example
rm -r "$mpchartlib_dir/MPChartExample"

patch "$mpchartlib_dir/settings.gradle" <<-'EOF'
@@ -1,6 +1,6 @@
 include 'MPChartLib'
 //include 'MPAndroidChart-Realm'
-include 'MPChartExample'
+//include 'MPChartExample'
 //include ':MPChartLib-Realm'
 //project(':MPChartLib-Realm').projectDir = new File('../MPAndroidChart-Realm/MPChartLib-Realm')
EOF

# BUILD: MPChartLib needs publishing to builder.osmand.net removing
# The site no longer exists and it causes dependency resolution errors even
# though not needed.
# Support OpenJDK 21.
patch "$mpchartlib_dir/MPChartLib/build.gradle" <<-'EOF'
@@ -1,14 +1,13 @@
 apply plugin: 'com.android.library'
-apply plugin: 'ivy-publish'
 
-group='com.github.philjay'
+group = 'com.github.philjay'
 
 android {
-    compileSdkVersion 28
-    buildToolsVersion '28.0.3'
+    namespace 'com.github.mikephil.charting'
+    compileSdkVersion 35
     defaultConfig {
         minSdkVersion 14
-        targetSdkVersion 28
+        targetSdkVersion 35
         versionCode 3
         versionName '3.1.0'
     }
@@ -23,32 +22,6 @@ android {
     }
 }
 
-afterEvaluate {
-    publishing {
-        repositories {
-            ivy {
-                url = System.getenv("OSMAND_BINARIES_IVY_ROOT") ?: "./"
-            }
-        }
-        publications {
-            release(IvyPublication) {
-                // Applies the component for the release build variant.
-                from components.release
-                organisation = 'net.osmand'
-                module = 'MPAndroidChart'
-                revision = 'custom-snapshot-release'
-            }
-            debug(IvyPublication) {
-                // Applies the component for the release build variant.
-                from components.debug
-                organisation = 'net.osmand'
-                module = 'MPAndroidChart'
-                revision = 'custom-snapshot-debug'
-            }
-        }
-    }
-}
-
 dependencies {
     implementation 'androidx.annotation:annotation:1.0.0'
     testImplementation 'junit:junit:4.12'
@@ -56,7 +29,7 @@ dependencies {
 
 task sourcesJar(type: Jar) {
     from android.sourceSets.main.java.srcDirs
-    classifier = 'sources'
+    archiveClassifier = 'sources'
 }
 
 task javadoc(type: Javadoc) {
@@ -67,7 +40,7 @@ task javadoc(type: Javadoc) {
 }
 
 task javadocJar(type: Jar, dependsOn: javadoc) {
-    classifier = 'javadoc'
+    archiveClassifier = 'javadoc'
     from javadoc.destinationDir
 }
EOF

patch "$mpchartlib_dir/build.gradle" <<-'EOF'
@@ -4,20 +4,12 @@ buildscript {
         mavenCentral()
     }
     dependencies {
-        classpath 'com.android.tools.build:gradle:4.2.2'
-        classpath 'com.github.dcendents:android-maven-gradle-plugin:2.1'
+        classpath 'com.android.tools.build:gradle:8.5.2'
     }
 }
 
 allprojects {
     repositories {
-        ivy {
-            name = "OsmAndBinariesIvy"
-            url = "https://builder.osmand.net"
-            patternLayout {
-                artifact "ivy/[organisation]/[module]/[revision]/[artifact]-[revision].[ext]"
-            }
-        }
         google()
         mavenCentral()
     }
EOF

patch "$mpchartlib_dir/gradle/wrapper/gradle-wrapper.properties" <<-'EOF'
@@ -3,4 +3,4 @@ distributionBase=GRADLE_USER_HOME
 distributionPath=wrapper/dists
 zipStoreBase=GRADLE_USER_HOME
 zipStorePath=wrapper/dists
-distributionUrl=https\://services.gradle.org/distributions/gradle-7.5.1-bin.zip
+distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
EOF

# BUILD: Make sure that libosmand.so (legacy core) is included in the APK

patch "$osmand_dir/build.gradle" <<-'EOF'
@@ -206,6 +206,11 @@
 
 afterEvaluate {
 	android.applicationVariants.configureEach { variant ->
+	        def mergeJniTaskName = "merge${variant.name.capitalize()}JniLibFolders"
+		tasks.named(mergeJniTaskName).configure {
+			dependsOn buildOsmAndCore
+		}
+
 		if (variant.name.contains('Opengldebug')) {
 			variant.javaCompileProvider.configure {
 				dependsOn collectExternalResources, buildOsmAndCore, copyOsmAndCoreWithJNI, cleanupDuplicatesInCore
EOF

# BUILD: Use legacy packaging else installation will fail with native
# libs error (-2)

sed -i \
    -e "s/sourceSets {/packagingOptions { jniLibs.useLegacyPackaging = true }\n\tsourceSets {/" \
    "$osmand_dir/build.gradle"

# BUILD: Remove some prebuilt jar libraries and replace with similar
# maven deps
#
# Replacements where versions did not match:
#   gnu-trove-osmand.jar replaced with net.sf.trove4j:trove4j:3.0.3
#
# icu4j-49_1_patched.jar was replaced with the icu50-2-1 srclib, a
# mirror of the nearest icu version available, plus the patch applied
# (http://bugs.icu-project.org/trac/ticket/12021). The build process
# compiles this and removes a bunch of unwanted data files.
#
# classes.jar is the FDroid-built version of the legacy core copied in
# by the build.sh script. Similarly for MPChartLib.
#
# $osmand_dir/build.gradle includes deps on QtAndroid.jar and
# QtAndroidBearer.jar from $osmand_dir/libs. These are deleted by FDroid
# and replaced by the ones built with the core in build.sh.

sed -i \
    -e "s/implementation fileTree.*/\
    implementation fileTree(include: ['icu4j.jar'], dir: 'libs')\\n \
    implementation group: 'net.sf.trove4j', name: 'trove4j', version: '3.0.3'\\n/" \
    "$osmand_java_dir/build.gradle"

sed -i \
    -e "s/implementation fileTree.*/\
    implementation fileTree(\
        include: ['icu4j.jar','MPChartLib-release.aar'], \
        dir: 'libs')\\n \
    implementation group: 'net.sf.trove4j', name: 'trove4j', version: '3.0.3'\\n/" \
    "$osmand_dir/build-common.gradle"

# BUILD (perhaps not essential): For code externally downloaded by the
# OsmAnd build, run a checksum test in cases it's not what we expect.
# First core-legacy, then core.

# checksum protobuf

sed -i \
    "s/# Extract/\
    sha256sum \$SRCLOC\/upstream.tar.bz2\\\
    | grep 13bfc5ae543cf3aa180ac2485c0bc89495e3ae711fc6fab4f8ffe90dfb4bb677\\\
    || { echo 'Failed checksum' 1>\&2; exit; }/"\
    "$core_legacy_dir/externals/protobuf/configure.sh"

# BUILD (perhaps not essential): core:
#   - checksum of tar/zip files for
#       - boost
#       - expat
#       - geographiclib
#       - giflib
#       - glew
#       - icu4c
#       - libpng
#       - protobuf
#       - sqlite
#       - zlib
#   - gits of
#       - freetype
#       - gdal
#       - glm
#       - jpeg
#       - libarchive
#       - proj
#       - qtbase-android
#       - skia (not using srclib because of build error)
#   - remove
#       - qtbase-desktop
#       - qtbase-ios

function addCheckSum() {
    local checksum="$1"
    local file="$2"
    sed -i \
        "s:patchUpstream.*:\
        echo $checksum \"\$SRCLOC/upstream.pack\" | sha256sum --check -\\\
        || { echo 'Failed checksum' 1>\&2; exit; }\n\0:"\
        "$file"
}

addCheckSum \
    8f32d4617390d1c2d16f26a27ab60d97807b35440d45891fa340fc2648b04406 \
    "$core_dir/externals/boost/configure.sh"

addCheckSum \
    6b902ab103843592be5e99504f846ec109c1abb692e85347587f237a4ffa1033 \
    "$core_dir/externals/expat/configure.sh"

addCheckSum \
    d16cae735dc6fd58317cad39cce73f19808a99fa6054fa587bd3d6a3ab621cb4 \
    "$core_dir/externals/geographiclib/configure.sh"

addCheckSum \
    0ac8d56726f77c8bc9648c93bbb4d6185d32b15ba7bdb702415990f96f3cb766 \
    "$core_dir/externals/giflib/configure.sh"

addCheckSum \
    af58103f4824b443e7fa4ed3af593b8edac6f3a7be3b30911edbc7344f48e4bf \
    "$core_dir/externals/glew/configure.sh"

addCheckSum \
    6d6fb937e671dd80490e19b8b70ea7c3c2a22de0e24793fc563bc87fe87a8eb1 \
    "$core_dir/externals/icu4c/configure.sh"

addCheckSum \
    42f754df633e4e700544e5913cbe2fd4928bbfccdc07708a5cf84e59827fbe60 \
    "$core_dir/externals/libpng/configure.sh"

addCheckSum \
    13bfc5ae543cf3aa180ac2485c0bc89495e3ae711fc6fab4f8ffe90dfb4bb677 \
    "$core_dir/externals/protobuf/configure.sh"

addCheckSum \
    a443aaf5cf345613492efa679ef1c9cc31ba109dcdf37ee377f61ab500d042fe \
    "$core_dir/externals/sqlite/configure.sh"

addCheckSum \
    a443aaf5cf345613492efa679ef1c9cc31ba109dcdf37ee377f61ab500d042fe \
    "$core_legacy_dir/externals/sqlite/configure.sh"

addCheckSum \
    c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1 \
    "$core_dir/externals/zlib/configure.sh"

rm -rf "$core_dir/externals/qtbase-desktop"
rm -rf "$core_dir/externals/qtbase-ios"

# BUILD: Remove billing code and options from menus, using stubs where
# needed.

cp "$stubs_dir/RateUsHelper.java" \
    "$osmand_dir/src/net/osmand/plus/feedback/RateUsHelper.java"
cp "$stubs_dir/InAppPurchaseHelperImpl.java" \
    "$osmand_dir/src-google/net/osmand/plus/inapp/InAppPurchaseHelperImpl.java"

rm "$osmand_dir/src-google/net/osmand/plus/inapp/util/BillingManager.java"
rm "$osmand_dir/src-google/net/osmand/plus/inapp/InAppPurchasesImpl.java"

sed -i -e "/.*Preference purchasesSettings.*/,+1d" \
    "$osmand_dir/src/net/osmand/plus/settings/fragments/MainSettingsFragment.java"
sed -i -e "/addRestorePurchasesRow();/d" \
    "$osmand_dir/src/net/osmand/plus/download/ui/DownloadResourceGroupFragment.java"
sed -i -e "s/return purchases.getSubscriptions();/\
    return new InAppSubscriptionList(new InAppSubscription[] { }) { };/" \
    "$osmand_dir/src/net/osmand/plus/inapp/InAppPurchaseHelper.java"
sed -i -e "s/return purchases\..*;/return null;/" \
    "$osmand_dir/src/net/osmand/plus/inapp/InAppPurchaseHelper.java"

# COSMETIC: hide purchase settings
perl -i -0 -p \
    -e 's|<Preference\n.*android:key="purchases_settings"(.*\n){9}||g' \
    "$osmand_dir/res/xml/settings_main_screen.xml"

# BUILD: Remove location services that needs Google stuff

rm "$osmand_dir/src/net/osmand/plus/helpers/GmsLocationServiceHelper.java"
sed -i \
    -e "s/GmsLocationServiceHelper/AndroidApiLocationServiceHelper/g" \
    "$osmand_dir/src/net/osmand/plus/OsmandApplication.java"

# COSMETIC: hide location services option (no longer works)

sed -i \
    -e 's/android:key="location_source"/\
    android:key="location_source" app:isPreferenceVisible="false"/' \
    "$osmand_dir/res/xml/global_settings.xml"

# CUSTOM: Enable file manager permission and remove warning about not
# being able to access files. See #2691.

sed -i \
    -e '/addItem(sharedStorageItem)/d' \
    "$osmand_dir/src/net/osmand/plus/settings/datastorage/DataStorageHelper.java"
sed -i \
    -e 's!<uses-permission android:name="android.permission.INTERNET" />!\
    <uses-permission android:name="android.permission.INTERNET" />\
    <uses-permission \
        android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />!' \
    "$osmand_dir/AndroidManifest.xml"

# BUILD (non-essential): remove signing configs (done by FDroid anyway, but
# needed for standalone build to succeed).

# first remove signing config opt lines in buildTypes, then delete block of
# signingConfigs.
sed -i \
    -e "/signingConfig signingConfigs\./d" \
    "$osmand_dir/build.gradle"
sed -i \
    -e "/signingConfigs/,+15d" \
    "$osmand_dir/build.gradle"

# BUILD: alter dummy ExcludeTLongObjectMap that uses the custom version of GNU
# Trove4j that is normally distributed as a binary .jar file. They changed the
# interface a little, so their dummy class overrides their custom interface.
# Change it back to the normal GNU Trove4j interface. Note, the binary .jar
# file also includes the source code. So we may want to -- in future -- extract
# the Java files and work it into the compile process.

excludetlongobjectmap="$osmand_java_dir/src/main/java/net/osmand/router/ExcludeTLongObjectMap.java"

sed -i \
    -e "s/forEachValue(TObjectProcedure<T>/forEachValue(TObjectProcedure<? super T>/" \
    $excludetlongobjectmap
sed -i \
    -e "s/forEachValue(TLongObjectProcedure<T>/forEachValue(TLongObjectProcedure<? super T>/" \
    $excludetlongobjectmap
sed -i \
    -e "s/forEachEntry(TLongObjectProcedure<T>/forEachEntry(TLongObjectProcedure<? super T>/" \
    $excludetlongobjectmap
sed -i \
    -e "s/retainEntries(TLongObjectProcedure<T>/retainEntries(TLongObjectProcedure<? super T>/" \
    $excludetlongobjectmap
sed -i \
    -e "s/putAll(TLongObjectMap<T>/putAll(TLongObjectMap<? extends T>/" \
    $excludetlongobjectmap
sed -i \
    -e "s/<T> T\[\] values/T\[\] values/" \
    $excludetlongobjectmap

# CUSTOM: Fixes the "INSTALL_FAILED_DUPLICATE_PERMISSION" issue, when trying to install additional variants of OsmAnd

sed -i "s/\"net.osmand.SERVICE_PERMISSION\"/\"net.osmand.plus.SERVICE_PERMISSION\"/g" "$osmand_dir/AndroidManifest.xml"

# BUILD: Reproducible build

patch "$core_dir/wrappers/android/build.gradle" <<-'EOF'
@@ -230,7 +230,7 @@
             include "**/*.*"
         }.collect {
             it.toURI().normalize().path.substring(resourcesDir.toURI().normalize().path.length())
-        }
+        }.sort()
         outputIndexFile.text = resources.join('\n')
     }
 }
EOF

# BUILD: Only build release and required arch of native lib, if a matching arch is passed.

if  [[ "$native_lib_arch" == "armv7" ]]
then
    sed -i \
        -e "s/BUILD_TYPE=\$1/BUILD_TYPE=\"release\"/g" \
        "$core_dir/wrappers/android/build.sh"
    patch "$core_dir/wrappers/android/build.sh" <<-'EOF'
	63,83d62
	< 
	< buildArch "arm64-v8a"
	< retcode=$?
	< if [[ $retcode -ne 0 ]]; then
	< 	echo "buildArch(arm64-v8a) failed with $retcode, exiting..."
	< 	exit $retcode
	< fi
	< 
	< buildArch "x86"
	< retcode=$?
	< if [[ $retcode -ne 0 ]]; then
	< 	echo "buildArch(x86) failed with $retcode, exiting..."
	< 	exit $retcode
	< fi
	< 
	< buildArch "x86_64"
	< retcode=$?
	< if [[ $retcode -ne 0 ]]; then
	<         echo "buildArch(x86_64) failed with $retcode, exiting..."
	<         exit $retcode
	< fi
	EOF
elif  [[ "$native_lib_arch" == "x86" ]]
then
    sed -i \
        -e "s/BUILD_TYPE=\$1/BUILD_TYPE=\"release\"/g" \
        "$core_dir/wrappers/android/build.sh"
    patch "$core_dir/wrappers/android/build.sh" <<-'EOF'
	57,70d56
	< buildArch "armeabi-v7a"
	< retcode=$?
	< if [[ $retcode -ne 0 ]]; then
	< 	echo "buildArch(armeabi-v7a) failed with $retcode, exiting..."
	< 	exit $retcode
	< fi
	< 
	< buildArch "arm64-v8a"
	< retcode=$?
	< if [[ $retcode -ne 0 ]]; then
	< 	echo "buildArch(arm64-v8a) failed with $retcode, exiting..."
	< 	exit $retcode
	< fi
	< 
	EOF
elif  [[ "$native_lib_arch" == "arm64" ]]
then
    sed -i \
        -e "s/BUILD_TYPE=\$1/BUILD_TYPE=\"release\"/g" \
        "$core_dir/wrappers/android/build.sh"
    patch "$core_dir/wrappers/android/build.sh" <<-'EOF'
	57,63d56
	< buildArch "armeabi-v7a"
	< retcode=$?
	< if [[ $retcode -ne 0 ]]; then
	< 	echo "buildArch(armeabi-v7a) failed with $retcode, exiting..."
	< 	exit $retcode
	< fi
	< 
	71,83d63
	< buildArch "x86"
	< retcode=$?
	< if [[ $retcode -ne 0 ]]; then
	< 	echo "buildArch(x86) failed with $retcode, exiting..."
	< 	exit $retcode
	< fi
	< 
	< buildArch "x86_64"
	< retcode=$?
	< if [[ $retcode -ne 0 ]]; then
	<         echo "buildArch(x86_64) failed with $retcode, exiting..."
	<         exit $retcode
	< fi
	EOF
fi

# BUILD: Fix the Gradle task order so that a single gradle assembleRelease is sufficient

patch "$core_dir/wrappers/android/build.gradle" <<-'EOF'
@@ -106,6 +106,7 @@
 tasks.register('copyNdkSharedLibs', Copy) {
     description = "Copy NDK shared libraries"
     dependsOn cleanupNdkSharedLibs
+    mustRunAfter("OsmAndCore_androidNative:buildOsmAndCore")
 
     def ndkRoot = System.getenv("ANDROID_NDK")
 
@@ -151,6 +152,7 @@
 tasks.register('copyQtSharedLibs', Copy) {
     description "Copy Qt shared libraries"
     dependsOn cleanupQtSharedLibs
+    mustRunAfter("OsmAndCore_androidNative:buildOsmAndCore")
 
     from("../../externals/qtbase-android") {
         include "upstream.patched.android.clang-*.shared/lib/libQt5Core.so"
@@ -174,6 +176,7 @@
 tasks.register('copyQtJarLibs', Copy) {
     description "Copy Qt JAR libraries"
     dependsOn cleanupQtJarLibs
+    mustRunAfter("OsmAndCore_androidNative:buildOsmAndCore")
 
     duplicatesStrategy = DuplicatesStrategy.EXCLUDE
EOF

# BUILD: Set the compile versions for qtbase-android to one supported by OpenJDK 21

patch "$core_dir/externals/qtbase-android/build.sh" <<-'EOF'
@@ -95,6 +95,7 @@ QTBASE_CONFIGURATION=$(echo "
 	-nomake tests -nomake examples -nomake tools -no-gui -no-widgets -no-cups -no-iconv -no-icu -no-dbus
 	-no-xcb -no-eglfs -no-directfb -no-linuxfb -no-kms -no-opengl -no-glib
 	-no-use-gold-linker
+	-android-javac-source 8 -android-javac-target 8
 	-v
 " | tr '\n' ' ')
EOF

# BUILD: Disable OsmAnd-java tests, because some will fail due to test resources (gzip files) being removed by "scandelete: - resources/test-resources" (metadata)

rm -r "$osmand_java_dir/src/test/java"

# return from whence we came (just in case)
popd

