// 全局 Electron 类型声明
// 用于解决 "Cannot find module 'electron'" 错误

declare module 'electron' {
  import { EventEmitter } from 'events';

  export interface BrowserWindow extends EventEmitter {
    id: number;
    webContents: WebContents;
    loadURL(url: string, options?: any): Promise<void>;
    loadFile(filePath: string, options?: any): Promise<void>;
    show(): void;
    hide(): void;
    close(): void;
    destroy(): void;
    focus(): void;
    isVisible(): boolean;
    isDestroyed(): boolean;
    setSize(width: number, height: number, animate?: boolean): void;
    getSize(): [number, number];
    setMinimumSize(width: number, height: number): void;
    setMaximumSize(width: number, height: number): void;
    setResizable(resizable: boolean): void;
    setMovable(movable: boolean): void;
    setClosable(closable: boolean): void;
    setMinimizable(minimizable: boolean): void;
    setMaximizable(maximizable: boolean): void;
    setFullScreenable(fullscreenable: boolean): void;
    setAlwaysOnTop(flag: boolean, level?: string, relativeLevel?: number): void;
    center(): void;
    setPosition(x: number, y: number, animate?: boolean): void;
    getPosition(): [number, number];
    setTitle(title: string): void;
    getTitle(): string;
    setSkipTaskbar(skip: boolean): void;
    setMenuBarVisibility(visible: boolean): void;
    setAutoHideMenuBar(hide: boolean): void;
    setBackgroundColor(color: string): void;
    setOpacity(opacity: number): void;
    setIgnoreMouseEvents(ignore: boolean, options?: { forward?: boolean }): void;
    setContentBounds(bounds: Rectangle, animate?: boolean): void;
    getContentBounds(): Rectangle;
    setContentSize(width: number, height: number, animate?: boolean): void;
    getContentSize(): [number, number];
    setBounds(bounds: Rectangle, animate?: boolean): void;
    getBounds(): Rectangle;
    setHasShadow(hasShadow: boolean): void;
    on(event: string, listener: (...args: any[]) => void): this;
    once(event: string, listener: (...args: any[]) => void): this;
    removeListener(event: string, listener: (...args: any[]) => void): this;
    removeAllListeners(event?: string): this;
  }

  export interface WebContents extends EventEmitter {
    id: number;
    session: Session;
    hostWebContents?: WebContents;
    devToolsWebContents?: WebContents;
    mainFrame: any;
    focusedFrame?: any;
    loadURL(url: string, options?: any): Promise<void>;
    loadFile(filePath: string, options?: any): Promise<void>;
    downloadURL(url: string): void;
    getURL(): string;
    getTitle(): string;
    isLoading(): boolean;
    isLoadingMainFrame(): boolean;
    stop(): void;
    reload(): void;
    reloadIgnoringCache(): void;
    canGoBack(): boolean;
    canGoForward(): boolean;
    canGoToOffset(offset: number): boolean;
    clearHistory(): void;
    goBack(): void;
    goForward(): void;
    goToIndex(index: number): void;
    goToOffset(offset: number): void;
    isCrashed(): boolean;
    setUserAgent(userAgent: string): void;
    getUserAgent(): string;
    insertCSS(css: string, options?: any): Promise<string>;
    executeJavaScript(code: string, userGesture?: boolean): Promise<any>;
    openDevTools(options?: any): void;
    closeDevTools(): void;
    isDevToolsOpened(): boolean;
    isDevToolsFocused(): boolean;
    toggleDevTools(): void;
    inspectElement(x: number, y: number): void;
    inspectServiceWorker(): void;
    send(channel: string, ...args: any[]): void;
    sendToFrame(frameId: number | [number, number], channel: string, ...args: any[]): void;
    enableDeviceEmulation(parameters: any): void;
    disableDeviceEmulation(): void;
    setZoomFactor(factor: number): void;
    getZoomFactor(): number;
    setZoomLevel(level: number): void;
    getZoomLevel(): number;
    setVisualZoomLevel(level: number): void;
    getVisualZoomLevel(): number;
    setLayoutZoomLevel(level: number): void;
    getLayoutZoomLevel(): number;
    on(event: string, listener: (...args: any[]) => void): this;
    once(event: string, listener: (...args: any[]) => void): this;
    removeListener(event: string, listener: (...args: any[]) => void): this;
    removeAllListeners(event?: string): this;
  }

  export interface Session extends EventEmitter {
    cookies: any;
    webRequest: any;
    protocol: any;
    clearCache(): Promise<void>;
    clearStorageData(options?: any): Promise<void>;
    flushStorageData(): void;
    setProxy(config: any): Promise<void>;
    setDownloadPath(path: string): void;
    enableNetworkEmulation(options: any): void;
    disableNetworkEmulation(): void;
    setCertificateVerifyProc(proc: any): void;
    setPermissionRequestHandler(handler: any): void;
    setPermissionCheckHandler(handler: any): void;
    clearHostResolverCache(): Promise<void>;
    clearAuthCache(options?: any): Promise<void>;
    allowNTLMCredentialsForDomains(domains: string): void;
    setUserAgent(userAgent: string, acceptLanguages?: string): void;
    getUserAgent(): string;
    getBlobData(identifier: string): Promise<Buffer>;
    downloadURL(url: string, options?: any): void;
    createInterruptedDownload(options: any): void;
    setPreloads(preloads: string[]): void;
    getPreloads(): string[];
    setSpellCheckerEnabled(enable: boolean): void;
    isSpellCheckerEnabled(): boolean;
    setSpellCheckerDictionaryDownloadURL(url: string): void;
    listWordsInSpellCheckerDictionary(): Promise<string[]>;
    addWordToSpellCheckerDictionary(word: string): boolean;
    removeWordFromSpellCheckerDictionary(word: string): boolean;
  }

  export interface IpcMain extends EventEmitter {
    handle(channel: string, listener: (event: IpcMainInvokeEvent, ...args: any[]) => Promise<any> | any): void;
    handleOnce(channel: string, listener: (event: IpcMainInvokeEvent, ...args: any[]) => Promise<any> | any): void;
    removeHandler(channel: string): void;
    on(channel: string, listener: (event: IpcMainEvent, ...args: any[]) => void): this;
    once(channel: string, listener: (event: IpcMainEvent, ...args: any[]) => void): this;
    removeListener(channel: string, listener: (event: IpcMainEvent, ...args: any[]) => void): this;
    removeAllListeners(channel?: string): this;
  }

  export interface IpcRenderer extends EventEmitter {
    invoke(channel: string, ...args: any[]): Promise<any>;
    send(channel: string, ...args: any[]): void;
    sendSync(channel: string, ...args: any[]): any;
    sendTo(webContentsId: number, channel: string, ...args: any[]): void;
    sendToHost(channel: string, ...args: any[]): void;
    postMessage(channel: string, message: any, transfer?: any[]): void;
    on(channel: string, listener: (event: IpcRendererEvent, ...args: any[]) => void): this;
    once(channel: string, listener: (event: IpcRendererEvent, ...args: any[]) => void): this;
    removeListener(channel: string, listener: (event: IpcRendererEvent, ...args: any[]) => void): this;
    removeAllListeners(channel?: string): this;
  }

  export interface App extends EventEmitter {
    quit(): void;
    exit(exitCode?: number): void;
    relaunch(options?: any): void;
    isReady(): boolean;
    whenReady(): Promise<void>;
    focus(): void;
    hide(): void;
    show(): void;
    setAppLogsPath(path?: string): void;
    getAppPath(): string;
    getPath(name: string): string;
    setPath(name: string, path: string): void;
    getVersion(): string;
    getName(): string;
    setName(name: string): void;
    getLocale(): string;
    getLocaleCountryCode(): string;
    addRecentDocument(path: string): void;
    clearRecentDocuments(): void;
    setAsDefaultProtocolClient(protocol: string, path?: string, args?: string[]): boolean;
    removeAsDefaultProtocolClient(protocol: string, path?: string, args?: string[]): boolean;
    isDefaultProtocolClient(protocol: string, path?: string, args?: string[]): boolean;
    getApplicationNameForProtocol(url: string): string;
    setUserTasks(tasks: any[]): void;
    getLoginItemSettings(options?: any): any;
    setLoginItemSettings(settings: any): void;
    isAccessibilitySupportEnabled(): boolean;
    setAccessibilitySupportEnabled(enabled: boolean): void;
    setAboutPanelOptions(options: any): void;
    showAboutPanel(): void;
    isEmojiPanelSupported(): boolean;
    showEmojiPanel(): void;
    setAppUserModelId(id: string): void;
    importCertificate(options: any, callback: (result: number) => void): void;
    disableHardwareAcceleration(): void;
    disableDomainBlockingFor3DAPIs(): void;
    getAppMetrics(): any[];
    getGPUFeatureStatus(): any;
    getGPUInfo(infoType: 'basic' | 'complete'): any;
    setBadgeCount(count?: number): boolean;
    getBadgeCount(): number;
    isUnityRunning(): boolean;
    getFileIcon(path: string, options?: any): Promise<NativeImage>;
    setJumpList(categories: any[] | null): void;
    requestSingleInstanceLock(additionalData?: Record<string, any>): boolean;
    releaseSingleInstanceLock(): void;
    hasSingleInstanceLock(): boolean;
    setUserActivity(type: string, userInfo: Record<string, any>, webpageURL?: string): void;
    getCurrentActivityType(): string;
    invalidateCurrentActivity(): void;
    resignCurrentActivity(): void;
    updateCurrentActivity(type: string, userInfo: Record<string, any>): void;
    setActivationPolicy(policy: 'regular' | 'accessory' | 'prohibited'): void;
    getSystemLocale(): string;
    getPreferredSystemLanguages(): string[];
    canCreateUntrustedDeveloperCertificates(): Promise<boolean>;
    createUntrustedDeveloperCertificate(issuerName: string, options?: any): Promise<string>;
    on(event: string, listener: (...args: any[]) => void): this;
    once(event: string, listener: (...args: any[]) => void): this;
    removeListener(event: string, listener: (...args: any[]) => void): this;
    removeAllListeners(event?: string): this;
  }

  export interface Tray extends EventEmitter {
    destroy(): void;
    setImage(image: NativeImage | string): void;
    setPressedImage(image: NativeImage | string): void;
    setToolTip(toolTip: string): void;
    setTitle(title: string, options?: any): void;
    getTitle(): string;
    setIgnoreDoubleClickEvents(ignore: boolean): void;
    getIgnoreDoubleClickEvents(): boolean;
    displayBalloon(options: any): void;
    removeBalloon(): void;
    focus(): void;
    popUpContextMenu(menu?: Menu, position?: Point): void;
    closeContextMenu(): void;
    setContextMenu(menu: Menu | null): void;
    getBounds(): Rectangle;
    isDestroyed(): boolean;
    on(event: string, listener: (...args: any[]) => void): this;
    once(event: string, listener: (...args: any[]) => void): this;
    removeListener(event: string, listener: (...args: any[]) => void): this;
    removeAllListeners(event?: string): this;
  }

  export interface Menu extends EventEmitter {
    static setApplicationMenu(menu: Menu | null): void;
    static getApplicationMenu(): Menu | null;
    static buildFromTemplate(template: any[]): Menu;
    popup(options?: any): void;
    closePopup(browserWindow?: BrowserWindow): void;
    append(menuItem: MenuItem): void;
    getMenuItemById(id: string): MenuItem | null;
    insert(pos: number, menuItem: MenuItem): void;
    items: MenuItem[];
    on(event: string, listener: (...args: any[]) => void): this;
  }

  export interface MenuItem extends EventEmitter {
    id: string;
    label: string;
    click: (menuItem: MenuItem, browserWindow: BrowserWindow | undefined, event: any) => void;
    submenu: MenuItem[] | Menu | null;
    type: 'normal' | 'separator' | 'submenu' | 'checkbox' | 'radio';
    role?: string;
    accelerator?: string;
    icon?: NativeImage | string;
    enabled: boolean;
    visible: boolean;
    checked: boolean;
    sublabel?: string;
    toolTip?: string;
    on(event: string, listener: (...args: any[]) => void): this;
  }

  export interface NativeImage {
    static createEmpty(): NativeImage;
    static createFromPath(path: string): NativeImage;
    static createFromBuffer(buffer: Buffer, options?: any): NativeImage;
    static createFromDataURL(dataURL: string): NativeImage;
    toPNG(options?: any): Buffer;
    toJPEG(quality: number): Buffer;
    toBitmap(options?: any): Buffer;
    toDataURL(options?: any): string;
    getBitmap(options?: any): Buffer;
    getNativeHandle(): Buffer;
    isEmpty(): boolean;
    getSize(): Size;
    setTemplateImage(option: boolean): void;
    isTemplateImage(): boolean;
    crop(rect: Rectangle): NativeImage;
    resize(options: any): NativeImage;
    getAspectRatio(): number;
    addRepresentation(options: any): void;
  }

  export interface Rectangle {
    x: number;
    y: number;
    width: number;
    height: number;
  }

  export interface Size {
    width: number;
    height: number;
  }

  export interface Point {
    x: number;
    y: number;
  }

  export interface IpcMainEvent {
    frameId: number;
    returnValue: any;
    sender: WebContents;
    senderFrame?: any;
    reply: (...args: any[]) => void;
  }

  export interface IpcMainInvokeEvent {
    frameId: number;
    sender: WebContents;
    senderFrame?: any;
  }

  export interface IpcRendererEvent {
    frameId: number;
    returnValue: any;
    sender: IpcRenderer;
    senderId: number;
  }

  export namespace Electron {
    export interface BrowserWindowConstructorOptions {
      width?: number;
      height?: number;
      x?: number;
      y?: number;
      useContentSize?: boolean;
      center?: boolean;
      minWidth?: number;
      minHeight?: number;
      maxWidth?: number;
      maxHeight?: number;
      resizable?: boolean;
      movable?: boolean;
      minimizable?: boolean;
      maximizable?: boolean;
      closable?: boolean;
      focusable?: boolean;
      alwaysOnTop?: boolean;
      fullscreen?: boolean;
      fullscreenable?: boolean;
      simpleFullscreen?: boolean;
      skipTaskbar?: boolean;
      kiosk?: boolean;
      title?: string;
      icon?: NativeImage | string;
      show?: boolean;
      frame?: boolean;
      parent?: BrowserWindow;
      modal?: boolean;
      acceptFirstMouse?: boolean;
      disableAutoHideCursor?: boolean;
      autoHideMenuBar?: boolean;
      enableLargerThanScreen?: boolean;
      backgroundColor?: string;
      hasShadow?: boolean;
      opacity?: number;
      darkTheme?: boolean;
      transparent?: boolean;
      type?: 'desktop' | 'dock' | 'toolbar' | 'splash' | 'notification';
      titleBarStyle?: 'default' | 'hidden' | 'hiddenInset' | 'customButtonsOnHover' | 'fullSize';
      titleBarOverlay?: boolean | any;
      fullscreenWindowTitle?: boolean;
      thickFrame?: boolean;
      vibrancy?: string;
      visualEffectState?: 'followWindow' | 'active' | 'inactive';
      zoomToPageWidth?: boolean;
      tabbingIdentifier?: string;
      webPreferences?: any;
      showInAllWorkspaces?: boolean;
      visibleOnAllWorkspaces?: boolean;
      roundedCorners?: boolean;
      trafficLightPosition?: Point;
    }
  }

  export const app: App;
  export const ipcMain: IpcMain;
  export const ipcRenderer: IpcRenderer;
  export const contextBridge: {
    exposeInMainWorld(apiKey: string, api: Record<string, any>): void;
  };

  export class BrowserWindow {
    constructor(options?: Electron.BrowserWindowConstructorOptions);
  }

  export class Tray {
    constructor(image: NativeImage | string, guid?: string);
  }

  export class Menu {
    static setApplicationMenu(menu: Menu | null): void;
    static getApplicationMenu(): Menu | null;
    static buildFromTemplate(template: any[]): Menu;
  }

  export class MenuItem {
    constructor(options: any);
  }

  export class NativeImage {
    static createEmpty(): NativeImage;
    static createFromPath(path: string): NativeImage;
    static createFromBuffer(buffer: Buffer, options?: any): NativeImage;
    static createFromDataURL(dataURL: string): NativeImage;
  }

  export function appWhenReady(): Promise<void>;
}
