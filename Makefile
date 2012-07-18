include theos/makefiles/common.mk

TWEAK_NAME = ClickToCall
ClickToCall_FILES = Tweak.xm
ClickToCall_FRAMEWORKS = UIKit AddressBook
ClickToCall_PRIVATE_FRAMEWORKS = AppSupport

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp CTPreferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/$(ECHO_END)
	$(ECHO_NOTHING)cp icon.png $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ClickToCall.png$(ECHO_END)