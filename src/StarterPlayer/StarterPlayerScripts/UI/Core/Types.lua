local BadgeService = game:GetService("BadgeService")
--!strict

export type Dict<T> = {[string]: T}
export type Array<T> = {T}

export type ParamSpec = {
    type: "string" | "boolean" | "number" | "color3" | "udim2" | "vector2" | "table", 
    default: any?,
    desc: string?
}

export type ParamSchema = Dict<ParamSpec>

export type NodeParams = {
    theme: string,
    hoverBg: Color3?,
    delegatedInput: boolean,
    appear: string?,
    appearDuration: number,
    tooltip: Dict<any>?,
    [string]: any,
}

export type BehaviorHandle = {
    Disconnect: (() -> ())?,
    DoCleaning: (() -> ())?,
}

export type BehaviorModule = {
    priority: number?,
    Requires: Array<string>?,

    Attach: (node: Node) -> BehaviorHandle?,
    Detach: (node: Node, handle: BehaviorHandle?) -> (),
}

-- ========= Policy contract =========

export type PolicyModule = {
    onOpen: (tree: Tree, node: Node) -> (),
    onClose: (tree: Tree, node: Node) -> (),
}

-- ========= Presets =========
export type Preset = {
    behaviors: Array<string>?,
    params: Dict<any>,
}

-- ========= Controller contract =========

export type Controller = {
	Init: ((self: Controller, node: Node, tree: Tree) -> ())?,
	OnOpen: ((self: Controller, data: any?) -> ())?,
	OnClose: ((self: Controller) -> ())?,
	OnParamChanged: ((self: Controller, key: string, value: any) -> ())?,
	OnDestroy: ((self: Controller) -> ())?,
	-- Store anything else controller wants:
	[string]: any,
}

-- ========= Update hub (Tick/Render/Second) =========

export type UpdateOpts = {
    whenOpen: boolean?,
    whenVisible: boolean?,
}

export type UpdateDisconnect = () -> ()

-- ========= Node / Tree =========

export type NodeKind = "menu" | "panel" | "overlay" | "button" | "hud" | "container" | "custom"

export type Node = {
	-- immutable-ish references
	Tree: Tree,
	Instance: GuiObject,
	Key: string,
	Kind: NodeKind,
	Group: string?,                -- mutex/stack/modal scope
	PolicyName: string?,           -- e.g. "Mutex", "Stack", "Modal"

	-- structure
	Parent: Node?,
	Children: Array<Node>,

	-- state
	Open: boolean,
	Params: NodeParams,
	Controller: Controller?,       
	Maid: any,               

	_behState: {
		locks: Dict<{ owner: string, prio: number }>,
	}?,
	_behHandles: Dict<BehaviorHandle>?,

	Tick: (self: Node, fn: (dt: number, node: Node) -> (), opts: UpdateOpts?) -> UpdateDisconnect,
	Render: (self: Node, fn: (dt: number, node: Node) -> (), opts: UpdateOpts?) -> UpdateDisconnect,
	TickSecond: (self: Node, fn: (elapsedSeconds: number, node: Node) -> (), opts: UpdateOpts?) -> UpdateDisconnect,

	Lock: (self: Node, prop: string, owner: string, prio: number) -> boolean,
	Unlock: (self: Node, prop: string, owner: string) -> (),
}

export type GroupMap = {[string]: {[string]: Node}}

export type Tree = {
    PlayerGui: PlayerGUi,

    -- lookups
    RootNodes: Array<Node>,
    Index: {[string]: Node},
    Groups: GroupMap,

    _stacks: {[string]: Array<Node>}?,

    -- public API
    Open: (self: Tree, key: string, data: any?) -> (),
    Close: (self: Tree, key: string) -> (),
    Toggle: (self: Tree, key: string) -> (),
    Get: (self: Tree, key: string) -> Node?,

    SetParam: (self: Tree, scopeKey: string, k: string, v: any, includeDescendants: boolean?) -> (),
    Begin: (self: Tree) -> (),
    Commit: (self: Tree) -> (),
    Rollback: (self: Tree) -> (),

    _applyOpen: (self: Tree, node: Node, open: boolean, instant: boolean?) -> (),
    BringToFront: ((self: Tree, node: Node) -> ())?,

    Changed: RBXScriptSignal?,
}

-- ========= Registries =========
export type BehaviorRegistry = {
    AttachForNode: (node: Node, bundle: {
        inherited: Array<string>?,
        preset: Array<string>?,
        overrides: string?,
    }) -> (),
    DetachAll: (node: Node) -> (),
}

export type PolicyRegistry = {
    Resolve: (classes: Array<string>) -> Preset,
}

export type HotkeyBinding = {
    key: Enum.KeyCode | Enum.UserInputType,
    action: {cmd: "open" | "close" | "toggle", arg: string},
    scope: "global" | "node" | "group",
    targetKey: string?,
    groupName: string?,
}

export type HotkeyRouter = {
    Add: (binding: HotkeyBinding) -> UpdateDisconnect,
}

export type ZIndexManager = {
    BringToFront: (node: Node) -> (),
    SetLayerBase: (groupName: string, BadgeService: number) -> (),
}

export type Transactions = {
    Begin: () -> (),
    Commit: () -> (), 
    Rollback: () -> (),
    InTransaction: () -> boolean,
}


local Types = {}
return Types
