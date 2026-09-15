Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'DirectedAcyclicGraph' {
        It 'rejects an edge that would create a cycle without changing the graph' {
            $Graph = [DirectedAcyclicGraph]::new()
            $Graph.AddNode('first')
            $Graph.AddNode('second')
            $Graph.AddEdge('first', 'second')

            { $Graph.AddEdge('second', 'first') } |
                Should -Throw "Adding edge from 'second' to 'first' would create a cycle."
            $Graph.GetTopologicalOrder() | Should -Be @('first', 'second')
        }

        It 'rejects edges containing an unknown node' {
            $Graph = [DirectedAcyclicGraph]::new()
            $Graph.AddNode('known')

            { $Graph.AddEdge('known', 'missing') } | Should -Throw "Node 'missing' does not exist."
        }

        It 'ignores duplicate edges' {
            $Graph = [DirectedAcyclicGraph]::new()
            $Graph.AddNode('first')
            $Graph.AddNode('second')

            $Graph.AddEdge('first', 'second')
            $Graph.AddEdge('first', 'second')

            $Graph.GetOutgoingEdges('first') | Should -Be @('second')
        }

        It 'returns a copy of outgoing edges' {
            $Graph = [DirectedAcyclicGraph]::new()
            $Graph.AddNode('first')
            $Graph.AddNode('second')
            $Graph.AddEdge('first', 'second')

            $Edges = $Graph.GetOutgoingEdges('first')
            $Edges[0] = 'changed'

            $Graph.GetOutgoingEdges('first') | Should -Be @('second')
        }

        It 'removes a node and all incoming edges' {
            $Graph = [DirectedAcyclicGraph]::new()
            $Graph.AddNode('root')
            $Graph.AddNode('removed')
            $Graph.AddNode('remaining')
            $Graph.AddEdge('root', 'removed')
            $Graph.AddEdge('removed', 'remaining')

            $Graph.RemoveNode('removed')

            $Graph.ContainsNode('removed') | Should -BeFalse
            $Graph.GetOutgoingEdges('root') | Should -BeNullOrEmpty
            $Graph.GetTopologicalOrder() | Should -Be @('root', 'remaining')
        }
    }
}

