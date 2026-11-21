Resources {
    $PropertyCategoryExpanderStyle = [System.Windows.Markup.XamlReader]::Parse(@'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
       xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
       TargetType="{x:Type Expander}">
    <Setter Property="Focusable" Value="False" />
    <Setter Property="Template">
        <Setter.Value>
            <ControlTemplate TargetType="{x:Type Expander}">
                <StackPanel>
                    <ToggleButton x:Name="HeaderSite"
                                  IsChecked="{Binding IsExpanded, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                        <ToggleButton.Template>
                            <ControlTemplate TargetType="{x:Type ToggleButton}">
                                <Border x:Name="HeaderBackground" Background="Transparent">
                                    <ContentPresenter />
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="HeaderBackground" Property="Background" Value="#F1F1F1" />
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </ToggleButton.Template>
                        <Grid Height="24">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="16" />
                                <ColumnDefinition Width="*" />
                            </Grid.ColumnDefinitions>
                            <Path x:Name="DisclosureArrow"
                                  Width="5"
                                  Height="8"
                                  HorizontalAlignment="Center"
                                  VerticalAlignment="Center"
                                  Data="M 0 0 L 5 4 L 0 8 Z"
                                  Fill="#606060" />
                            <ContentPresenter x:Name="HeaderContent"
                                              Grid.Column="1"
                                              VerticalAlignment="Center"
                                              Content="{TemplateBinding Header}"
                                              ContentTemplate="{TemplateBinding HeaderTemplate}"
                                              ContentTemplateSelector="{TemplateBinding HeaderTemplateSelector}"
                                              RecognizesAccessKey="True" />
                        </Grid>
                    </ToggleButton>
                    <Border x:Name="ContentBorder" Padding="16,2,0,6">
                        <ContentPresenter ContentSource="Content" />
                    </Border>
                    <Border x:Name="CategoryDivider"
                            Height="1"
                            Background="#D8D8D8"
                            SnapsToDevicePixels="True" />
                </StackPanel>
                <ControlTemplate.Triggers>
                    <Trigger Property="IsExpanded" Value="False">
                        <Setter TargetName="ContentBorder" Property="Visibility" Value="Collapsed" />
                    </Trigger>
                    <Trigger Property="IsExpanded" Value="True">
                        <Setter TargetName="DisclosureArrow" Property="Data" Value="M 0 0 L 8 0 L 4 5 Z" />
                        <Setter TargetName="DisclosureArrow" Property="Width" Value="8" />
                        <Setter TargetName="DisclosureArrow" Property="Height" Value="5" />
                    </Trigger>
                </ControlTemplate.Triggers>
            </ControlTemplate>
        </Setter.Value>
    </Setter>
</Style>
'@)
    $this['PropertyCategoryExpanderStyle'] = $PropertyCategoryExpanderStyle

    # Scoped to the enclosing Window so it only affects controls on the design surface.
    Style Label {
        BorderBrush: '#999999'
        BorderThickness: 1
        Padding: 4

        Trigger IsMouseOver $true {
            BorderBrush: '#2563EB'
            Background: '#EFF6FF'
        }
    }

    # Flattens the resize handle: the default Thumb chrome has an OS-themed
    # bevel/gradient that's hard to make out at this control's small size.
    Style Thumb {
        Template {
            Border 'ThumbBorder' {
                Background: (TemplateBinding Background)
                BorderBrush: (TemplateBinding BorderBrush)
                BorderThickness: (TemplateBinding BorderThickness)
            }
        }
    }
}
