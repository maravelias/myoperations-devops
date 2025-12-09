<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true>
<!DOCTYPE html>
<html lang="${locale.current}">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="robots" content="noindex, nofollow" />
  <title><#nested "title"></title>

  <#if properties.stylesCommon?has_content>
    <#list properties.stylesCommon?split(' ') as style>
      <link href="${url.resourcesCommonPath}/${style}" rel="stylesheet" />
    </#list>
  </#if>
  <#if properties.styles?has_content>
    <#list properties.styles?split(' ') as style>
      <link href="${url.resourcesPath}/${style}" rel="stylesheet" />
    </#list>
  </#if>
  <#nested "head">
</head>

<body class="mo-login-body ${bodyClass}">
  <div class="mo-login-shell">
    <aside class="mo-login-hero">
      <p class="mo-login-hero__badge">${msg("loginHeroBadge")}</p>
      <h1 class="mo-login-hero__title">${msg("loginHeroTitle")}</h1>
      <p class="mo-login-hero__subtitle">${msg("loginHeroSubtitle")}</p>
      <p class="mo-login-hero__footnote">${msg("loginHeroFootnote")}</p>
    </aside>

    <main class="mo-login-panel" aria-live="polite">
      <div class="mo-login-panel__chrome">
        <#if realm.internationalizationEnabled && locale.supported?size gt 1>
          <div class="locale-container" id="kc-locale">
            <img src="${url.resourcesPath}/img/globe.svg" alt="${msg('selectLocale')}" />
            <div class="${properties.kcLocaleWrapperClass!}">
              <div id="kc-locale-dropdown" class="${properties.kcLocaleDropDownClass!}">
                <a href="#" id="kc-current-locale-link">${locale.current}</a>
                <ul class="${properties.kcLocaleListClass!}">
                  <#list locale.supported as l>
                    <li class="${properties.kcLocaleListItemClass!}">
                      <a class="${properties.kcLocaleItemClass!}" href="${l.url}">${l.label}</a>
                    </li>
                  </#list>
                </ul>
              </div>
            </div>
          </div>
        </#if>

        <#nested "logo">

        <#if displayMessage && message?has_content>
          <div class="mo-alert mo-alert--${message.type}">
            <span>${message.summary?no_esc}</span>
          </div>
        </#if>

        <#nested "form">
      </div>
    </main>
  </div>
</body>
</html>
</#macro>
