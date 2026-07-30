export interface TabBarProps {
  /** Title-case labels; text only, never icons */
  items: string[];
  active: string;
  onSelect?: (tab: string) => void;
}
export declare function TabBar(props: TabBarProps): JSX.Element;
