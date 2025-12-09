<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
  <#if section = "title">
    ${msg("loginAccountTitle")}

  <#elseif section = "head">
    <link rel="icon" type="image/png" href="${url.resourcesPath}/img/logo.png" />
    <script>
      document.addEventListener("DOMContentLoaded", function () {
        const passwordInput = document.getElementById("password");
        const toggleButton = document.getElementById("toggle-password");
        const toggleIcon = document.getElementById("password-toggle-icon");
        if (!passwordInput || !toggleButton || !toggleIcon) {
          return;
        }
        const labels = {
          show: "${msg("showPassword")?js_string}",
          hide: "${msg("hidePassword")?js_string}"
        };
        const icons = {
          show: "${url.resourcesPath}/img/eye.svg",
          hide: "${url.resourcesPath}/img/eye-off.svg"
        };
        toggleButton.addEventListener("click", function () {
          const masked = passwordInput.type === "password";
          passwordInput.type = masked ? "text" : "password";
          toggleButton.setAttribute("aria-pressed", masked ? "true" : "false");
          toggleIcon.src = masked ? icons.show : icons.hide;
          toggleIcon.alt = masked ? labels.hide : labels.show;
          toggleButton.setAttribute("aria-label", masked ? labels.hide : labels.show);
        });
      });
    </script>

  <#elseif section = "logo">
    <div class="mo-brand">
      <img src="${url.resourcesPath}/img/logo.png" alt="${msg('brandAltText')}" />
      <div class="mo-brand__copy">
        <div class="mo-brand__title">${msg("loginTitleHtml")?no_esc}</div>
        <p class="mo-brand__subtitle">${msg("loginSubTitle")}</p>
      </div>
    </div>

  <#elseif section = "form">
    <div class="box-container">
      <p class="mo-form-intro">${msg("loginFormIntro")}</p>

      <#if realm.password>
        <form id="kc-form-login" class="form" action="${url.loginAction}" method="post" novalidate>
          <#assign autoFocusTarget = "username">
          <#if usernameHidden?? || usernameEditDisabled??>
            <#assign autoFocusTarget = "password">
          </#if>

          <#if usernameHidden??>
            <input type="hidden" id="username" name="username" value="${usernameHidden?html}" />
          <#else>
            <div class="field-group">
              <label for="username">${msg("usernameOrEmail")}</label>
              <div class="field-control">
                <span class="field-icon" aria-hidden="true">
                  <img src="${url.resourcesPath}/img/user.svg" alt="" />
                </span>
                <input
                  type="text"
                  id="username"
                  name="username"
                  value="${(login.username!'')?html}"
                  autocomplete="username"
                  <#if autoFocusTarget == "username">autofocus</#if>
                  <#if usernameEditDisabled??>disabled="disabled" readonly="readonly"</#if>
                  required
                />
              </div>
            </div>
          </#if>

          <div class="field-group">
            <label for="password">${msg("password")}</label>
            <div class="field-control">
              <input
                type="password"
                id="password"
                name="password"
                autocomplete="current-password"
                <#if autoFocusTarget == "password">autofocus</#if>
                required
              />
              <button
                type="button"
                class="visibility"
                id="toggle-password"
                aria-label="${msg("showPassword")}"
                aria-pressed="false"
              >
                <img id="password-toggle-icon" src="${url.resourcesPath}/img/eye-off.svg" alt="${msg("showPassword")}" />
              </button>
            </div>
          </div>

          <div class="form-aux">
            <#if realm.rememberMe && !usernameHidden??>
              <label class="checkbox">
                <#if login.rememberMe??>
                  <input id="rememberMe" name="rememberMe" type="checkbox" checked />
                <#else>
                  <input id="rememberMe" name="rememberMe" type="checkbox" />
                </#if>
                <span>${msg("rememberMe")}</span>
              </label>
            </#if>

            <#if realm.resetPasswordAllowed>
              <a class="form-link" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a>
            </#if>
          </div>

          <#if auth?has_content && auth.selectedCredential??>
            <input type="hidden" name="credentialId" value="${auth.selectedCredential.id}" />
          </#if>

          <div class="form-actions">
            <button class="submit" type="submit" name="login" id="kc-login">${msg("doLogIn")}</button>
          </div>
        </form>
      </#if>

      <#if realm.registrationAllowed && !registrationDisabled??>
        <p class="mo-register">
          ${msg("loginRegisterPrompt")}
          <a href="${url.registrationUrl}">${msg("doRegister")}</a>
        </p>
      </#if>

      <#if realm.password && social?? && social.providers?has_content>
        <div id="kc-social-providers" class="${properties.kcFormSocialAccountSectionClass!}">
          <div class="social-divider">
            <span>${msg("identity-provider-login-label")}</span>
          </div>
          <ul class="${properties.kcFormSocialAccountListClass!} <#if social.providers?size gt 3>${properties.kcFormSocialAccountListGridClass!}</#if>">
            <#list social.providers as p>
              <li>
                <a
                  id="social-${p.alias}"
                  class="${properties.kcFormSocialAccountListButtonClass!} <#if social.providers?size gt 3>${properties.kcFormSocialAccountGridItem!}</#if>"
                  type="button"
                  href="${p.loginUrl}"
                >
                  <#if p.iconClasses?has_content>
                    <i class="${properties.kcCommonLogoIdP!} ${p.iconClasses!}" aria-hidden="true"></i>
                    <span class="${properties.kcFormSocialAccountNameClass!} kc-social-icon-text">${p.displayName!}</span>
                  <#else>
                    <span class="${properties.kcFormSocialAccountNameClass!}">${p.displayName!}</span>
                  </#if>
                </a>
              </li>
            </#list>
          </ul>
        </div>
      </#if>
    </div>

    <div class="mo-footer">
      <p class="copyright">&copy; ${msg("copyright", "${.now?string('yyyy')}")}</p>
      <p class="mo-footer__note">${msg("loginFooterNote")}</p>
    </div>
  </#if>
</@layout.registrationLayout>
